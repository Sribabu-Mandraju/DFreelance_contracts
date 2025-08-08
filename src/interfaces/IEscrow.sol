// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IEscrow {
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

    // State variable getters
    function usdcToken() external view returns (address);
    function treasury() external view returns (address);
    function governanceContract() external view returns (address);
    function proposalBalances(uint256 proposalId) external view returns (uint256);

    // Governance functions
    function setGovernanceContract(address _governance) external;

    // Payment functions
    function depositFunds(uint256 proposalId, uint256 amount) external;
    function processPayment(uint256 proposalId, address client, address bidder, uint256 amount, uint256 feeBasisPoints)
        external;
    function refundToClient(uint256 proposalId, address client) external;

    // Emergency function
    function emergencyWithdraw(address to, uint256 amount) external;
}
