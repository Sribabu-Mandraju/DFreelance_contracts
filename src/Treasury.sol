// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Treasury is Ownable {
    error Treasury__insufficientBalance();
    error Treasury__withdrawFailed();

    address public usdcTokenAddress;

    constructor(address _initialOwner, address _usdcTokenAddress) Ownable(_initialOwner) {
        usdcTokenAddress = _usdcTokenAddress; // Initialize the token address
    }

    function withDrawAmount(uint256 _amount) external onlyOwner {
        if (IERC20(usdcTokenAddress).balanceOf(address(this)) < _amount) {
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
