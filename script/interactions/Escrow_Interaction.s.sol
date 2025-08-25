// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Escrow} from "../../src/Escrow.sol";

contract Escrow_Interaction is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("WALLET_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        Escrow esc = Escrow(0x7BeaCDbE4Ac6219DB0a1695743427B613B0cb2Fb);
        esc.setGovernanceContract(0xc127810479D1366AA3672066C737C98c97735134);
        vm.stopBroadcast();
    }
}
