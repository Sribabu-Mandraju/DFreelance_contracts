// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IHFTtoken {
    // Token metadata
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);

    // Claim functionality
    function claimTokens() external;
    function lastClaimTime(address user) external view returns (uint256);
    function CLAIM_INTERVAL() external view returns (uint256);
    function CLAIM_AMOUNT() external view returns (uint256);

    // Transfer controls
    function transfersEnabled() external view returns (bool);
    function enableTransfers(bool _enabled) external;

    // Owner functions
    function mintHFT(address _to, uint256 _amount) external;
    function burnHFT(address _onBehalfOf, uint256 _amount) external;
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;

    // Standard ERC20 functions
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
