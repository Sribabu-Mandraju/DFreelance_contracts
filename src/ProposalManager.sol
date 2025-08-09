// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IEscrow} from "./interfaces/IEscrow.sol";
import "./types/DataTypes.sol";
import "./types/Errors.sol";
import "./types/Events.sol";

contract ProposalManager {
    using SafeERC20 for IERC20;

    // Constants with default values (can be updated by DAO)
    uint256 public FIRST_PAYMENT_PERCENT = 40;
    uint256 public SECOND_PAYMENT_PERCENT = 30;
    uint256 public THIRD_PAYMENT_PERCENT = 30;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public PLATFORM_FEE_BASICPOINTS = 100;
    uint256 public bidFee = 25e18;

    // State variables
    uint256 public proposalCount;
    address public treasury;
    address public platformToken;
    address public escrow;
    IERC20 public usdcToken;

    // Mappings
    mapping(uint256 => Proposal) public proposals;
    mapping(address => DaoMember) public daoMembers;
    ImprovementProposal[] private improvementProposals;
    address[] private memberAddresses;

    // Modifiers
    modifier onlyClient(uint256 proposalId) {
        _validateProposalExists(proposalId);
        if (msg.sender != proposals[proposalId].client) {
            revert OnlyClientCanCall(msg.sender);
        }
        _;
    }

    modifier onlyBidder(uint256 proposalId) {
        _validateProposalExists(proposalId);
        if (msg.sender != proposals[proposalId].bidder) {
            revert OnlyBidderCanCall(msg.sender);
        }
        _;
    }

    modifier onlyManager() {
        if (daoMembers[msg.sender].role != Role.MANAGER) {
            revert NotAuthorized();
        }
        _;
    }

    constructor(
        address[] memory _members,
        Role[] memory _roles,
        uint256 _platformFee,
        address _treasury,
        address _platformToken,
        address _usdcToken,
        address _escrowContract,
        uint256 _bidFee
    ) {
        require(_members.length == _roles.length, "Arrays length mismatch");

        // Add initial members
        for (uint256 i = 0; i < _members.length; i++) {
            _addDaoMember(_members[i], _roles[i]);
        }

        // Add deployer as manager
        _addDaoMember(msg.sender, Role.MANAGER);

        PLATFORM_FEE_BASICPOINTS = _platformFee;
        treasury = _treasury;
        platformToken = _platformToken;
        usdcToken = IERC20(_usdcToken);
        bidFee = _bidFee;
        escrow = _escrowContract;
    }

    // ========== DAO Management Functions ========== //

    /**
     * @notice Update payment milestones percentages (must sum to 100)
     * @param first First payment percentage
     * @param second Second payment percentage
     * @param third Third payment percentage
     */
    function updatePaymentPercentages(uint256 first, uint256 second, uint256 third) external onlyManager {
        require(first + second + third == 100, "Sum must equal 100");

        FIRST_PAYMENT_PERCENT = first;
        SECOND_PAYMENT_PERCENT = second;
        THIRD_PAYMENT_PERCENT = third;

        emit PaymentPercentagesUpdated(first, second, third,block.timestamp);
    }

    /**
     * @notice Update platform fee basis points
     * @param newFee New fee in basis points (1% = 100)
     */
    function updatePlatformFee(uint256 newFee) external onlyManager {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        PLATFORM_FEE_BASICPOINTS = newFee;
        emit PlatformFeeUpdated(newFee);
    }

    /**
     * @notice Update bid fee amount
     * @param newBidFee New bid fee amount (in token decimals)
     */
    function updateBidFee(uint256 newBidFee) external onlyManager {
        bidFee = newBidFee;
        emit BidFeeUpdated(newBidFee);
    }

    /**
     * @notice Update treasury address
     * @param newTreasury New treasury address
     */
    function updateTreasury(address newTreasury) external onlyManager {
        require(newTreasury != address(0), "Invalid address");
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury,block.timestamp);
    }

    /**
     * @notice Update escrow contract address
     * @param newEscrow New escrow contract address
     */
    function updateEscrow(address newEscrow) external onlyManager {
        require(newEscrow != address(0), "Invalid address");
        escrow = newEscrow;
        emit EscrowUpdated(newEscrow,block.timestamp);
    }

    // External Functions

    function createProposal(uint256 _deadline, uint256 _budget) external {
        if (msg.sender == address(0)) {
            revert InvalidAddress(msg.sender);
        }
        if (_budget == 0) {
            revert InvalidBudget(_budget);
        }
        if (_deadline <= block.timestamp) {
            revert InvalidTime(block.timestamp, _deadline);
        }

        uint256 newProposalId = proposalCount++;
        proposals[newProposalId] = Proposal({
            id: newProposalId,
            client: msg.sender,
            bidder: address(0),
            startTime: block.timestamp,
            endTime: _deadline,
            budget: _budget,
            bidAmount: 0,
            state: uint8(ProposalState.Draft)
        });

        emit ProposalCreated(newProposalId, msg.sender);
    }

    function openProposalToBid(uint256 proposalId) external onlyClient(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == uint8(ProposalState.Draft), "Invalid proposal state");
        _updateProposalState(proposalId, ProposalState.Active);
    }

    function acceptBid(uint256 proposalId, address _bidder, uint256 _bidAmount) external onlyClient(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == uint8(ProposalState.Active), "Invalid proposal state");
        if (proposal.bidder != address(0)) {
            revert BidderAlreadyExists();
        }

        proposal.bidder = _bidder;
        proposal.bidAmount = _bidAmount;
        _updateProposalState(proposalId, ProposalState.Awarded);

        emit BidPlaced(proposalId, _bidder);
    }

    // In ProposalManager.sol
    function depositBidAmount(uint256 proposalId) external onlyClient(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == uint8(ProposalState.Awarded), "Invalid state");

        // Transfer USDC from client (Alex) to ProposalManager first
        usdcToken.safeTransferFrom(msg.sender, address(this), proposal.bidAmount);

        // Then approve Escrow and deposit
        usdcToken.approve(address(escrow), proposal.bidAmount);
        IEscrow(escrow).depositFunds(proposalId, proposal.bidAmount);

        _updateProposalState(proposalId, ProposalState.Funded);
    }

    function startWork(uint256 proposalId) external onlyBidder(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == uint8(ProposalState.Funded), InvalidProposalState());
        _updateProposalState(proposalId, ProposalState.InProgress);
    }

    function payFirstMilestone(uint256 proposalId) external onlyClient(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.state != uint8(ProposalState.InProgress)) {
            revert InvalidStateForPayment(proposalId, proposal.state);
        }

        uint256 paymentAmount = _calculatePercentage(proposal.bidAmount, FIRST_PAYMENT_PERCENT);
        _processPayment(proposalId, paymentAmount);
        _updateProposalState(proposalId, ProposalState.MilestonePayout_ONE);
    }

    function paySecondMilestone(uint256 proposalId) external onlyClient(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == uint8(ProposalState.MilestonePayout_ONE), InvalidProposalState());

        uint256 paymentAmount = _calculatePercentage(proposal.bidAmount, SECOND_PAYMENT_PERCENT);
        _processPayment(proposalId, paymentAmount);
        _updateProposalState(proposalId, ProposalState.MilestonePayout_TWO);
    }

    function payThirdMilestone(uint256 proposalId) external onlyClient(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == uint8(ProposalState.MilestonePayout_TWO), "Invalid state for payment");

        uint256 paymentAmount = _calculatePercentage(proposal.bidAmount, THIRD_PAYMENT_PERCENT);
        _processPayment(proposalId, paymentAmount);
        _updateProposalState(proposalId, ProposalState.MilestonePayout_THREE);
    }

    function completeProposal(uint256 proposalId) external onlyClient(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == uint8(ProposalState.MilestonePayout_THREE), InvalidProposalState());
        _updateProposalState(proposalId, ProposalState.Completed);
    }

    function cancelProposal(uint256 proposalId) external onlyClient(proposalId) {
        Proposal memory proposal = proposals[proposalId];
        _updateProposalState(proposalId, ProposalState.Cancelled);
        IEscrow(escrow).refundToClient(proposalId, proposal.client);
    }

    // Admin Functions

    function addDaoMember(address _member, Role _role) external onlyManager {
        _addDaoMember(_member, _role);
    }

    function removeDaoMember(address _member) external onlyManager {
        delete daoMembers[_member];

        // Remove from addresses array
        for (uint256 i = 0; i < memberAddresses.length; i++) {
            if (memberAddresses[i] == _member) {
                memberAddresses[i] = memberAddresses[memberAddresses.length - 1];
                memberAddresses.pop();
                break;
            }
        }

        emit DaoMemberRemoved(_member);
    }

    function setPlatformFee(uint256 _newFee) external onlyManager {
        PLATFORM_FEE_BASICPOINTS = _newFee;
        emit PlatformFeeUpdated(_newFee);
    }

    function setBidFee(uint256 _newBidFee) external onlyManager {
        bidFee = _newBidFee;
        emit BidFeeUpdated(_newBidFee);
    }

    // View Functions

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        _validateProposalExists(proposalId);
        return proposals[proposalId];
    }

    function getAllProposals() external view returns (Proposal[] memory) {
        Proposal[] memory allProposals = new Proposal[](proposalCount);
        for (uint256 i = 0; i < proposalCount; i++) {
            allProposals[i] = proposals[i];
        }
        return allProposals;
    }

    function getPaginatedProposals(uint256 offset, uint256 limit) external view returns (Proposal[] memory) {
        uint256 end = offset + limit;
        if (end > proposalCount) end = proposalCount;
        if (end < offset) return new Proposal[](0);

        Proposal[] memory result = new Proposal[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = proposals[i];
        }
        return result;
    }

    function getDaoMembers() external view returns (DaoMember[] memory) {
        DaoMember[] memory members = new DaoMember[](memberAddresses.length);
        for (uint256 i = 0; i < memberAddresses.length; i++) {
            members[i] = daoMembers[memberAddresses[i]];
        }
        return members;
    }

    // Internal Functions

    function _addDaoMember(address _member, Role _role) internal {
        require(_member != address(0), "Invalid address");
        require(daoMembers[_member].member == address(0), "Member already exists");

        daoMembers[_member] = DaoMember(_member, _role);
        memberAddresses.push(_member);
        emit DaoMemberAdded(_member, uint8(_role));
    }

    function _updateProposalState(uint256 proposalId, ProposalState newState) internal {
        Proposal storage proposal = proposals[proposalId];

        // Validate state transitions
        if (
            proposal.state == uint8(ProposalState.Completed) || proposal.state == uint8(ProposalState.Cancelled)
                || proposal.state == uint8(ProposalState.Refunded)
        ) {
            revert CantModifyFinalState();
        }

        // Role-based state transition checks
        if (
            // Add milestone payments to client-only actions
            newState == ProposalState.Awarded || newState == ProposalState.Funded || newState == ProposalState.Cancelled
                || newState == ProposalState.MilestonePayout_ONE || newState == ProposalState.MilestonePayout_TWO
                || newState == ProposalState.MilestonePayout_THREE || newState == ProposalState.Completed
        ) {
            if (msg.sender != proposal.client) {
                revert OnlyClientCanCall(msg.sender);
            }
        }
        // Only allow bidder to transition from Funded → InProgress
        else if (newState == ProposalState.InProgress) {
            if (msg.sender != proposal.bidder) revert OnlyBidderCanStartWork();
            if (proposal.state != uint8(ProposalState.Funded)) {
                revert MustBeInFundedState();
            }
        }

        // Special case for Disputed state
        if (newState == ProposalState.Disputed) {
            if (msg.sender != proposal.client && msg.sender != proposal.bidder) {
                revert OnlyClientOrBidderCanDispute();
            }
        }

        // Validate sequential milestones
        if (newState == ProposalState.MilestonePayout_TWO && proposal.state != uint8(ProposalState.MilestonePayout_ONE))
        {
            revert MustCompleteMilestone1First();
        }
        if (
            newState == ProposalState.MilestonePayout_THREE
                && proposal.state != uint8(ProposalState.MilestonePayout_TWO)
        ) {
            revert MustCompleteMilestone2First();
        }

        proposal.state = uint8(newState);
        emit ProposalStateUpdated(proposalId, uint8(newState), block.timestamp);
    }

    function _processPayment(uint256 proposalId, uint256 amount) internal {
        Proposal storage proposal = proposals[proposalId];

        // (
        //     uint256 feeAmount,
        //     uint256 bidderAmount
        // ) = _calculatePlatformFeeAndPayment(amount);

        // Transfer fee to treasury
        // usdcToken.safeTransfer(treasury, feeAmount);
        IEscrow(escrow).processPayment(proposalId, proposal.client, proposal.bidder, amount, PLATFORM_FEE_BASICPOINTS);

        // Transfer to bidder
        // usdcToken.safeTransfer(proposal.bidder, bidderAmount);

        emit PaymentSuccessful(proposalId, proposal.client, amount);
    }

    function _calculatePercentage(uint256 amount, uint256 percentage) internal pure returns (uint256) {
        return (amount * percentage) / 100;
    }

    function _calculatePlatformFeeAndPayment(uint256 amount) internal view returns (uint256 fee, uint256 payment) {
        fee = (amount * PLATFORM_FEE_BASICPOINTS) / BASIS_POINTS;
        payment = amount - fee;
    }

    function _validateProposalExists(uint256 proposalId) internal view {
        if (proposalId >= proposalCount) {
            revert InvalidProposalId(proposalId);
        }
    }

    function getPlatformFee() public view returns (uint256) {
        return PLATFORM_FEE_BASICPOINTS;
    }
}
