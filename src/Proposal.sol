// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Proposal {
    error Proposal__invalidAddress(address user);
    error Proposal__invalidBudget(uint256 amount);
    error Proposal__invalidTime(uint256 startTime, uint256 endTime);
    error Proposal__onlyClientCanCall(address caller);
    error Proposal__onlyBidderCanCall(address caller);
    error Proposal__cantModifyFinalStateOfProposal();
    error Proposal__invalidProposalState();
    error Proposal__bidderAlreadyExists();
    error Proposal__paymentFailed();

    error Proposal__invalidStateToPayFirstInstantOfPayment(uint256 proposalId, ProposalState currentState);

    event ProposalStateUpdated(uint256 indexed _proposalId, ProposalState indexed _newState, uint256 indexed timestamp);
    event FirstInstantPaymentSuccessfuk(uint256 indexed _proposalId, address indexed _client, uint256 indexed _amount);

    enum ProposalState {
        Draft, // Created but not published (optional)
        Active, // Open for bidding
        Awarded, // Client selected a bidder (bid accepted)   ok
        Funded, // Client deposited funds in this contract    ok
        InProgress, // Work started
        MilestonePayout_ONE, // Partial payment released for a milestone
        MilestonePayout_TWO, // Partial payment released for a milestone
        MilestonePayout_THREE, // Partial payment released for a milestone
        Completed, // Work delivered & fully paid
        Disputed, // Conflict raised (under arbitration)
        Cancelled, // Client/bidder cancelled before completion  ok
        Refunded // Funds returned (if cancelled/disputed)

    }

    modifier onlyBidder() {
        require(msg.sender == bidderAddress, Proposal__onlyClientCanCall(msg.sender));
        _;
    }

    modifier onlyClient() {
        require(msg.sender == clientAddress, Proposal__onlyBidderCanCall(msg.sender));
        _;
    }

    uint256 public immutable proposalId;
    address public immutable clientAddress;
    address public bidderAddress;
    uint256 public immutable FIRST_INSTANT_PAYMENT_PERCENTAGE = 40;
    uint256 public immutable SECOND_INSTANT_PAYMENT_PERCENTAGE = 30;
    uint256 public immutable THIRD_INSTANT_PAYMENT_PERCENTAGE = 30;
    uint256 public platformFeeBasisPoints = 100;

    uint256 public startTime;
    uint256 public endTime;
    uint256 public budget;
    IERC20 private immutable usdcTokenAddress = IERC20(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
    address public immutable treasury;

    ProposalState public proposalState;

    constructor(
        uint256 _proposalId,
        address _clientAddress,
        uint256 _deadLine,
        uint256 _budget,
        address _treasuryAddress
    ) {
        if (_clientAddress == address(0)) {
            revert Proposal__invalidAddress(_clientAddress);
        }
        if (_budget < 0) {
            revert Proposal__invalidBudget(_budget);
        }

        if (_deadLine < block.timestamp) {
            revert Proposal__invalidTime(startTime, endTime);
        }
        proposalId = _proposalId;
        clientAddress = _clientAddress;
        proposalState = ProposalState.Draft;
        budget = _budget;
        treasury = _treasuryAddress;
    }

    // function to make proposal biddable by bidders
    function openProposalToBid() public onlyClient {
        require(proposalState == ProposalState.Draft, Proposal__invalidProposalState());
        _updateProposalState(ProposalState.Active);
        emit ProposalStateUpdated(proposalId, proposalState, block.timestamp);
    }

    // function to hire bidder for work
    function acceptBid(address _bidder, uint256 _bidAmount) public onlyClient {
        require(proposalState == ProposalState.Active, Proposal__invalidProposalState());
        if (bidderAddress != address(0)) {
            revert Proposal__bidderAlreadyExists();
        }
        _updateProposalState(ProposalState.Awarded);
        budget = _bidAmount;
        bidderAddress = _bidder;
    }

    // deposits budget amount of usdc tokens in this contract
    function depositBidAmount() public onlyClient {
        require(proposalState == ProposalState.Awarded, Proposal__invalidProposalState());
        _updateProposalState(ProposalState.Funded);
        bool success = usdcTokenAddress.transferFrom(msg.sender, address(this), budget);
        require(success, Proposal__paymentFailed());
    }

    function startWork() public onlyBidder {
        require(proposalState == ProposalState.Funded, Proposal__invalidProposalState());
        _updateProposalState(ProposalState.InProgress);
    }

    // first instant payment functionality
    function payFirstInstantOfPayment() public onlyClient {
        require(
            proposalState == ProposalState.InProgress,
            Proposal__invalidStateToPayFirstInstantOfPayment(proposalId, proposalState)
        );

        // Calculate 40% payment
        uint256 paymentAmount = _calculatePercentage(budget, FIRST_INSTANT_PAYMENT_PERCENTAGE);

        // Calculate fee and remaining amount
        (uint256 feeAmount, uint256 bidderAmount) = _calculatePlatformFeeAndActualPayment(paymentAmount);

        // Transfer fee to treasurer
        bool success = usdcTokenAddress.transfer(treasury, feeAmount);
        require(success, "Fee transfer failed");

        // Transfer to bidder
        success = usdcTokenAddress.transfer(bidderAddress, bidderAmount);
        require(success, Proposal__paymentFailed());

        _updateProposalState(ProposalState.MilestonePayout_ONE);
        emit FirstInstantPaymentSuccessfuk(proposalId, msg.sender, bidderAmount);
    }

    function paySecondInstantOfPayment() public onlyClient {
        require(proposalState == ProposalState.MilestonePayout_ONE, "Invalid state for second payment");

        uint256 paymentAmount = _calculatePercentage(budget, SECOND_INSTANT_PAYMENT_PERCENTAGE);
        (uint256 feeAmount, uint256 bidderAmount) = _calculatePlatformFeeAndActualPayment(paymentAmount);

        usdcTokenAddress.transfer(treasury, feeAmount);
        usdcTokenAddress.transfer(bidderAddress, bidderAmount);

        _updateProposalState(ProposalState.MilestonePayout_TWO);
    }

    function payThirdInstantOfPayment() public onlyClient {
        require(proposalState == ProposalState.MilestonePayout_TWO, "Invalid state for third payment");

        uint256 paymentAmount = _calculatePercentage(budget, THIRD_INSTANT_PAYMENT_PERCENTAGE);
        (uint256 feeAmount, uint256 bidderAmount) = _calculatePlatformFeeAndActualPayment(paymentAmount);

        usdcTokenAddress.transfer(treasury, feeAmount);
        usdcTokenAddress.transfer(bidderAddress, bidderAmount);

        _updateProposalState(ProposalState.MilestonePayout_THREE);
    }

    function endProposalTask() public onlyClient {
        require(proposalState == ProposalState.MilestonePayout_THREE, Proposal__invalidProposalState());
        _updateProposalState(ProposalState.Completed);
    }

    function cancelProposal() public onlyClient {
        _updateProposalState(ProposalState.Cancelled);
    }

    function _updateProposalState(ProposalState newState) internal {
        // Validate state transitions
        if (
            proposalState == ProposalState.Completed || proposalState == ProposalState.Cancelled
                || proposalState == ProposalState.Refunded
        ) {
            revert Proposal__cantModifyFinalStateOfProposal();
        }

        // Role-based state transition checks
        if (
            newState == ProposalState.Awarded || newState == ProposalState.Funded || newState == ProposalState.Cancelled
        ) {
            require(msg.sender == clientAddress, Proposal__onlyClientCanCall(msg.sender));
        } else if (
            newState == ProposalState.InProgress || newState == ProposalState.MilestonePayout_ONE
                || newState == ProposalState.MilestonePayout_TWO || newState == ProposalState.MilestonePayout_THREE
                || newState == ProposalState.Completed
        ) {
            require(msg.sender == bidderAddress, Proposal__onlyBidderCanCall(msg.sender));
        }

        // Special case for Disputed state (either party can initiate)
        if (newState == ProposalState.Disputed) {
            require(msg.sender == clientAddress || msg.sender == bidderAddress, "Only client or bidder can dispute");
        }

        // Validate sequential milestones
        if (newState == ProposalState.MilestonePayout_TWO && proposalState != ProposalState.MilestonePayout_ONE) {
            revert("Must complete Milestone 1 first");
        }
        if (newState == ProposalState.MilestonePayout_THREE && proposalState != ProposalState.MilestonePayout_TWO) {
            revert("Must complete Milestone 2 first");
        }

        proposalState = newState;
        emit ProposalStateUpdated(proposalId, newState, block.timestamp);
    }

    function _calculatePercentage(uint256 amount, uint256 percentage) internal pure returns (uint256) {
        return (amount * percentage) / 100;
    }

    function _calculatePlatformFeeAndActualPayment(uint256 amount)
        internal
        view
        returns (uint256 fee, uint256 remaining)
    {
        fee = (amount * platformFeeBasisPoints) / 10000;
        remaining = amount - fee;
    }
}
