// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HFTtoken} from "../src/HFTtoken.sol";
import {Treasury} from "../src/Treasury.sol";
import {ProposalManager} from "../src/ProposalManager.sol";
import {MockUSDC} from "../test/mock/MockUSDC.sol";
import {Escrow} from "../src/Escrow.sol";
import {DaoMember, Role} from "../src/types/DataTypes.sol";
import {PLATFORM_FEE_BASEIC_POINTS, BID_FEE} from "../src/types/Constants.sol";

contract DeployLocal is Script {
    Treasury treasury;
    HFTtoken ourToken;
    MockUSDC usdcToken;
    Escrow escrowContract;
    ProposalManager proposalManager;

    address public ANVIL_DEFAULT_PUBLIC_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external returns (ProposalManager, Escrow, address, HFTtoken, Treasury) {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // ==============  deploying mock usdc contract ==================

        usdcToken = new MockUSDC();

        // ============== deploying treasury contract ====================

        treasury = new Treasury(ANVIL_DEFAULT_PUBLIC_ADDRESS, address(usdcToken));

        // ============== deploying escrow contract =======================

        escrowContract = new Escrow(address(usdcToken), address(treasury), ANVIL_DEFAULT_PUBLIC_ADDRESS);

        //=============== deploying HFT token contract ======================
        ourToken = new HFTtoken(ANVIL_DEFAULT_PUBLIC_ADDRESS, address(usdcToken));

        // ============== deploying proposal manager contract ================
        address[] memory daoMembers = new address[](2);
        daoMembers[0] = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
        daoMembers[1] = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955;

        Role[] memory roles = new Role[](2);
        roles[0] = Role.DAO_MEMBER;
        roles[1] = Role.DAO_MEMBER;

        proposalManager = new ProposalManager(
            daoMembers,
            roles,
            PLATFORM_FEE_BASEIC_POINTS,
            address(treasury),
            address(ourToken),
            address(usdcToken),
            address(escrowContract),
            BID_FEE
        );
        vm.stopBroadcast();

        console.log("usdc contract address :", address(usdcToken));
        console.log("HFT token contract address :", address(ourToken));
        console.log("treasury contract address :", address(treasury));
        console.log("escrow contract address :", address(escrowContract));
        console.log("Proposal Management contract address :", address(proposalManager));

        return (proposalManager, escrowContract, address(usdcToken), ourToken, treasury);
    }
}
