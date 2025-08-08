// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Governer} from "../src/Governer.sol";
import {HFTtoken} from "../src/HFTtoken.sol";
import {Treasury} from "../src/Treasury.sol";
import {ProposalManager} from "../src/ProposalManager.sol";
import {MockUSDC} from "../test/mock/MockUSDC.sol";
import {Escrow} from "../src/Escrow.sol";
import {DaoMember, Role} from "../src/types/DataTypes.sol";
import {PLATFORM_FEE_BASEIC_POINTS, BID_FEE} from "../src/types/Constants.sol";

contract DeployBase is Script {
    function run() external returns (ProposalManager, Escrow, address, HFTtoken, Treasury) {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("WALLET_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        // DAO members (replace with actual Base addresses)
        address[] memory daoMembers = new address[](2);
        daoMembers[0] = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f; // Replace with Base address
        daoMembers[1] = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955; // Replace with Base address

        Role[] memory roles = new Role[](2);
        roles[0] = Role.DAO_MEMBER;
        roles[1] = Role.DAO_MEMBER;

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy MockUSDC (or use real USDC on Base)
        // MockUSDC usdcToken = new MockUSDC();
        
        // 2. Deploy Treasury
        Treasury treasury = new Treasury(deployerAddress, 0x036CbD53842c5426634e7929541eC2318f3dCF7e);
        
        // 3. Deploy Escrow
        Escrow escrowContract = new Escrow(
            0x036CbD53842c5426634e7929541eC2318f3dCF7e,
            address(treasury),
            deployerAddress
        );
        
        // 4. Deploy HFT Token
        HFTtoken ourToken = new HFTtoken(deployerAddress);
        
        // 5. Deploy ProposalManager
        ProposalManager proposalManager = new ProposalManager(
            daoMembers,
            roles,
            PLATFORM_FEE_BASEIC_POINTS,
            address(treasury),
            address(ourToken),
            0x036CbD53842c5426634e7929541eC2318f3dCF7e,
            address(escrowContract),
            BID_FEE
        );

        vm.stopBroadcast();

        // Log addresses (visible in forge scripts)
        console.log("USDC Address:", 0x036CbD53842c5426634e7929541eC2318f3dCF7e);
        console.log("Treasury Address:", address(treasury));
        console.log("Escrow Address:", address(escrowContract));
        console.log("HFT Token Address:", address(ourToken));
        console.log("ProposalManager Address:", address(proposalManager));

        return (proposalManager, escrowContract, 0x036CbD53842c5426634e7929541eC2318f3dCF7e, ourToken, treasury);
    }
}