// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Changed from interfaces to token

contract Treasury is Ownable {
    error Treasury__insufficientBalance();
    error Treasury__withdrawFailed();
    error Treasury__invalidTokenAddress();

    address public immutable usdcTokenAddress;

    constructor(address _initialOwner, address _usdcTokenAddress) Ownable(_initialOwner) {
        require(_usdcTokenAddress != address(0), "Invalid token address");
        usdcTokenAddress = _usdcTokenAddress;
    }

    function withDrawAmount(uint256 _amount) external onlyOwner {
        uint256 balance = IERC20(usdcTokenAddress).balanceOf(address(this));
        if (balance < _amount) {
            revert Treasury__insufficientBalance();
        }
        bool success = IERC20(usdcTokenAddress).transfer(msg.sender, _amount);
        if (!success) {
            revert Treasury__withdrawFailed();
        }
    }

    function getTotalTreasureBalance() public view returns (uint256) {
        return IERC20(usdcTokenAddress).balanceOf(address(this));
    }
}
