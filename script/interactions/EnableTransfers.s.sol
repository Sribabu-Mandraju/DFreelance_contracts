// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HFTtoken} from "../../src/HFTtoken.sol";

contract EnableTransfer is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("WALLET_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        HFTtoken token = HFTtoken(0x0feBB9594586Fd1626E33e63AB8B966b58eC9682);
        token.enableTransfers(true);
        vm.stopBroadcast();
    }
}
