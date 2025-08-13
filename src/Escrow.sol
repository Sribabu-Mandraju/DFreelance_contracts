// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Changed from interfaces to token
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Escrow is Ownable {
    using SafeERC20 for IERC20;

    // Custom Errors
    error InvalidAddress();
    error InvalidAmount();
    error TransferFailed();
    error Unauthorized();
    error AlreadyProposalFundsAreUsed();

    // Events
    event PaymentProcessed(
        uint256 indexed proposalId,
        address indexed client,
        address indexed bidder,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );
    event FundsDeposited(uint256 indexed proposalId, address indexed from, uint256 amount, uint256 timestamp);
    event FundsWithdrawn(uint256 indexed proposalId, address indexed to, uint256 amount, uint256 timestamp);

    // State Variables
    address public immutable usdcToken;
    address public immutable treasury;
    address public governanceContract;

    // Mapping to track balances per proposal
    mapping(uint256 => uint256) public proposalBalances;
    uint256 public totalLockedFunds; // Tracks sum of all proposal balances

    modifier onlyGovernance() {
        if (msg.sender != governanceContract) {
            revert Unauthorized();
        }
        _;
    }

    constructor(address _usdcToken, address _treasury, address _initialOwner) Ownable(_initialOwner) {
        if (_usdcToken == address(0) || _treasury == address(0)) {
            revert InvalidAddress();
        }
        usdcToken = _usdcToken;
        treasury = _treasury;
    }

    // ========== GETTER FUNCTIONS ========== //

    /**
     * @notice Returns the total USDC balance held by this contract
     * @return The total USDC balance (locked + unlocked)
     */
    function getTotalContractBalance() public view returns (uint256) {
        return IERC20(usdcToken).balanceOf(address(this));
    }

    /**
     * @notice Returns the total funds locked in all proposals
     * @return The sum of all proposal balances
     */
    function getTotalLockedFunds() public view returns (uint256) {
        return totalLockedFunds;
    }

    /**
     * @notice Returns the available (unlocked) USDC balance
     * @return The amount of USDC not assigned to any proposal
     */
    function getAvailableBalance() public view returns (uint256) {
        return getTotalContractBalance() - totalLockedFunds;
    }

    /**
     * @notice Returns the balance for a specific proposal
     * @param proposalId The ID of the proposal to check
     * @return The USDC balance for this proposal
     */
    function getProposalBalance(uint256 proposalId) public view returns (uint256) {
        return proposalBalances[proposalId];
    }

    // ========== SETTER FUNCTIONS ========== //

    function setGovernanceContract(address _governance) external onlyOwner {
        if (_governance == address(0)) {
            revert InvalidAddress();
        }
        governanceContract = _governance;
    }

    // Deposit funds into escrow for a specific proposal
    function depositFunds(uint256 proposalId, uint256 amount) public {
        if (amount == 0) {
            revert InvalidAmount();
        }

        IERC20(usdcToken).safeTransferFrom(msg.sender, address(this), amount);
        proposalBalances[proposalId] += amount;
        totalLockedFunds += amount;

        emit FundsDeposited(proposalId, msg.sender, amount, block.timestamp);
    }

    // Process payment with fee deduction
    function processPayment(uint256 proposalId, address client, address bidder, uint256 amount, uint256 feeBasisPoints)
        external
        onlyGovernance
    {
        if (amount == 0 || bidder == address(0)) {
            revert InvalidAmount();
        }

        uint256 balance = proposalBalances[proposalId];
        if (balance < amount) {
            revert InvalidAmount();
        }

        // Calculate fee and payment amounts
        uint256 feeAmount = (amount * feeBasisPoints) / 10000;
        uint256 paymentAmount = amount - feeAmount;

        // Update balances
        proposalBalances[proposalId] = balance - amount;
        totalLockedFunds -= amount;

        // Transfer funds
        IERC20(usdcToken).safeTransfer(treasury, feeAmount);
        IERC20(usdcToken).safeTransfer(bidder, paymentAmount);

        emit PaymentProcessed(proposalId, client, bidder, paymentAmount, feeAmount, block.timestamp);
    }

    // Refund funds to client
    function refundToClient(uint256 proposalId, address client) external onlyGovernance {
        uint256 balance = proposalBalances[proposalId];
        if (balance == 0) {
            revert AlreadyProposalFundsAreUsed();
        }

        IERC20(usdcToken).safeTransfer(client, balance);
        proposalBalances[proposalId] = 0;
        totalLockedFunds -= balance;

        emit FundsWithdrawn(proposalId, client, balance, block.timestamp);
    }

    // Emergency withdrawal by owner (only for non-proposal funds)
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        uint256 availableBalance = getAvailableBalance();
        if (amount > availableBalance) {
            revert InvalidAmount();
        }

        IERC20(usdcToken).safeTransfer(to, amount);
    }
}
