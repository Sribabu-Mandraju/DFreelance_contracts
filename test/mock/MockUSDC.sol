// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSDC is ERC20, Ownable {
    // USDC uses 6 decimals (1,000,000 = 1 USDC)
    uint8 private constant _decimals = 6;

    constructor() ERC20("Mock USD Coin", "mUSDC") Ownable(msg.sender) {
        // Mint 1,000,000 mock USDC to the deployer (1,000,000 * 10^6)
        _mint(msg.sender, 1000000 * (10 ** uint256(_decimals)));
    }

    // Override decimals to return 6 instead of default 18
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    // Function to mint new tokens (only owner can call this)
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    // Function to burn tokens (only owner can call this)
    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }
}
