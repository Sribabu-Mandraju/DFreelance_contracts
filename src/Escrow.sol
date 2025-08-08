// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
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

        // Update balance
        proposalBalances[proposalId] = balance - amount;

        // Transfer funds
        IERC20(usdcToken).safeTransfer(treasury, feeAmount);
        IERC20(usdcToken).safeTransfer(bidder, paymentAmount);

        emit PaymentProcessed(proposalId, client, bidder, paymentAmount, feeAmount, block.timestamp);
    }

    // Refund funds to client
    function refundToClient(uint256 proposalId, address client) external onlyGovernance {
        // if (amount == 0 || client == address(0)) {
        //     revert InvalidAmount();
        // }

        uint256 balance = proposalBalances[proposalId];
        if (balance == 0) {
            revert AlreadyProposalFundsAreUsed();
        }

        IERC20(usdcToken).safeTransfer(client, balance);
        proposalBalances[proposalId] = 0;

        emit FundsWithdrawn(proposalId, client, balance, block.timestamp);
    }

    // Emergency withdrawal by owner (only for non-proposal funds)
    // function emergencyWithdraw(
    //     address to,
    //     uint256 amount
    // ) external onlyOwner {
    //     uint256 contractBalance = IERC20(usdcToken).balanceOf(address(this));
    //     uint256 lockedFunds = 0;

    //     // Calculate total locked funds in all proposals
    //     // Note: In production, you might want to track this separately
    //     // to avoid gas costs of iterating through all proposals
    //     for (uint256 i = 0; i < type(uint256).max; i++) {
    //         lockedFunds += proposalBalances[i];
    //         // Break if we've checked all possible proposals
    //         if (lockedFunds >= contractBalance) break;
    //     }

    //     uint256 availableAmount = contractBalance - lockedFunds;
    //     if (amount > availableAmount) {
    //         revert InvalidAmount();
    //     }

    //     IERC20(usdcToken).safeTransfer(to, amount);
    // }
}
