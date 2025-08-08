// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24; // Made version consistent

import {Script} from "forge-std/Script.sol";
import {Governer} from "../src/Governer.sol";
import {HFTtoken} from "../src/HFTtoken.sol";
import {MockUSDC} from "../test/mock/MockUSDC.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address deployerAddress;
        address usdcToken;
        address hftTokenAddr;
        uint256 deployerPrivateKey;
    }

    NetworkConfig public activeNetworkConfig;

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public constant DEFAULT_ANVIL_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    constructor() {
        activeNetworkConfig = getAnvilNetworkConfig();
    }

    function getAnvilNetworkConfig() public returns (NetworkConfig memory) {
        return NetworkConfig({
            deployerAddress: DEFAULT_ANVIL_ADDRESS,
            usdcToken: getMockUSDCTokenAddress(),
            hftTokenAddr: getHFTtokenAddress(),
            deployerPrivateKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }

    function getMockUSDCTokenAddress() internal returns (address) {
        MockUSDC usdcToken = new MockUSDC();
        return address(usdcToken);
    }

    function getHFTtokenAddress() internal returns (address) {
        HFTtoken hftToken = new HFTtoken(DEFAULT_ANVIL_ADDRESS);
        return address(hftToken);
    }
}
