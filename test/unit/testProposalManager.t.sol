// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ProposalManager} from "../../src/ProposalManager.sol";
import {DeployLocal} from "../../script/DeployLocal.s.sol";

import {HFTtoken} from "../../src/HFTtoken.sol";
import {Treasury} from "../../src/Treasury.sol";
import {ProposalManager} from "../../src/ProposalManager.sol";
import {MockUSDC} from "../../test/mock/MockUSDC.sol";
import {Escrow} from "../../src/Escrow.sol";
import {DaoMember, Proposal} from "../../src/types/DataTypes.sol";
import {IEscrow} from "../../src/interfaces/IEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TestProposalManager is Test {
    HFTtoken c_HFToken;
    Treasury c_Treasury;
    ProposalManager c_ProposalManager;
    Escrow c_Escrow;
    address usdcToken;

    address deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address alex = makeAddr("alex");
    address bob = makeAddr("star");

    DeployLocal deploys;

    function setUp() public {
        deploys = new DeployLocal();
        (
            c_ProposalManager,
            c_Escrow,
            usdcToken,
            c_HFToken,
            c_Treasury
        ) = deploys.run();

        vm.startPrank(deployer);
        c_Escrow.setGovernanceContract(address(c_ProposalManager));
        vm.stopPrank();
    }

    function testCountTotalDaoMembers() public view {
        DaoMember[] memory totalDaoMembers = c_ProposalManager.getDaoMembers();
        assertEq(totalDaoMembers.length, 3);
    }

    // struct Proposal {
    //     uint256 id;
    //     address client;
    //     address bidder;
    //     uint256 startTime;
    //     uint256 endTime;
    //     uint256 budget;
    //     uint256 bidAmount;
    //     uint8 state;
    // }

    function testCreateProposal() public {
        vm.startPrank(alex);
        c_ProposalManager.createProposal(10 days, 10 * 1e6);
        vm.stopPrank();
        Proposal memory proposal = c_ProposalManager.getProposal(0);
        // (uint256 proposalId,address client,address bidder,uint256 startTime,uint256 endTime,uint256 budget,uint256 bidAmount,uint8 proposalState) = proposal;
        assertEq(proposal.client, alex, "invalid client");
        assertEq(proposal.bidder, address(0), "address must be 0 address");
        assertEq(
            proposal.endTime,
            uint256(proposal.startTime + 10 days - 1),
            "invalid time"
        );
        assertEq(proposal.budget, 10 * 1e6);
        assertEq(proposal.bidAmount, 0);
        assertEq(proposal.state, 0);
    }

    function testOpenProposalToBid() public createProposal {
        vm.startPrank(alex);
        c_ProposalManager.openProposalToBid(0);
        Proposal memory proposal = c_ProposalManager.getProposal(0);
        assertEq(proposal.state, 1);
        vm.stopPrank();
    }

    function testAcceptbid() public createProposal {
        vm.startPrank(alex);
        c_ProposalManager.openProposalToBid(0);
        c_ProposalManager.acceptBid(0, bob, 7 * 1e6);
        Proposal memory proposal = c_ProposalManager.getProposal(0);
        assertEq(proposal.bidder, bob);
        assertEq(proposal.bidAmount, 7 * 1e6);
        vm.stopPrank();
    }

    // function testDepositBidAmount() public createProposal {
    //     // minting usdc tokens to alex account
    //     vm.startPrank(deployer);
    //     MockUSDC(usdcToken).mint(alex, 7 * 1e6);
    //     vm.stopPrank();

    //     vm.startPrank(alex);
    //     c_ProposalManager.openProposalToBid(0);
    //     c_ProposalManager.acceptBid(0, bob, 7 * 1e6);
    //     Proposal memory proposal = c_ProposalManager.getProposal(0);
    //     assertEq(proposal.bidder, bob);
    //     assertEq(proposal.bidAmount, 7 * 1e6);

    //     // depositing bid amount
    //     IERC20(usdcToken).approve(address(c_Escrow), 7e6);
    //     uint256 amountAllowance = IERC20(usdcToken).allowance(alex, address(c_Escrow));
    //     console.log(amountAllowance);
    //     c_ProposalManager.depositBidAmount(0);
    //     vm.stopPrank();

    // }

    function testDepositBidAmount() public createProposal {
        // 1. Mint USDC to Alex
        vm.startPrank(deployer);
        MockUSDC(usdcToken).mint(alex, 7 * 1e6);
        vm.stopPrank();

        vm.startPrank(alex);
        // 2. Create and accept bid
        c_ProposalManager.openProposalToBid(0);
        c_ProposalManager.acceptBid(0, bob, 7 * 1e6);

        // 3. Approve ProposalManager to spend Alex's USDC (CRITICAL FIX)
        IERC20(usdcToken).approve(address(c_ProposalManager), 7 * 1e6);

        // 4. Deposit bid amount
        c_ProposalManager.depositBidAmount(0);
        vm.stopPrank();

        // Verify escrow balance
        assertEq(IERC20(usdcToken).balanceOf(address(c_Escrow)), 7 * 1e6);
    }

    function testStartWork() public {
        testDepositBidAmount();
        vm.startPrank(bob);
        c_ProposalManager.startWork(0);
        Proposal memory proposal = c_ProposalManager.getProposal(0);
        assertEq(proposal.state, 4);
        vm.stopPrank();
    }

    function testFirstPayment() public {
        testStartWork();
        vm.startPrank(alex);
        c_ProposalManager.payFirstMilestone(0);
        vm.stopPrank();
        uint256 treasuryBalance = c_Treasury.getTotalTreasureBalance();
        assertEq(treasuryBalance, 28000);
        assertEq(IERC20(usdcToken).balanceOf(bob), 2800000 - treasuryBalance);
        uint256 afterProposalBalance = c_Escrow.proposalBalances(0);
        Proposal memory proposal = c_ProposalManager.getProposal(0);
        assertEq(proposal.bidAmount - 2800000, afterProposalBalance);
    }

    function testSecondPayment() public {
        testFirstPayment();
        vm.startPrank(alex);
        c_ProposalManager.paySecondMilestone(0);
        vm.stopPrank();
        uint256 treasuryBalance = c_Treasury.getTotalTreasureBalance();
        assertEq(treasuryBalance, 49000);
        uint256 bobBalance = IERC20(usdcToken).balanceOf(bob);
        assertEq(bobBalance, 4851000);
        uint256 afterProposalBalance = c_Escrow.proposalBalances(0);
        assertEq(afterProposalBalance, 7e6 - bobBalance - treasuryBalance);
    }

    function testThirdPayment() public {
        testSecondPayment();
        vm.startPrank(alex);
        c_ProposalManager.payThirdMilestone(0);
        vm.stopPrank();

        uint256 treasuryBalance = c_Treasury.getTotalTreasureBalance();
        assertEq(treasuryBalance, 70000);
        uint256 bobBalance = IERC20(usdcToken).balanceOf(bob);
        assertEq(bobBalance, 6930000);
        uint256 afterProposalBalance = c_Escrow.proposalBalances(0);
        assertEq(afterProposalBalance, 0);
    }

    function testCompleteProposal() public {
        testThirdPayment();
        vm.startPrank(alex);
        c_ProposalManager.completeProposal(0);

        vm.expectRevert();
        c_ProposalManager.cancelProposal(0);
        vm.stopPrank();
    }

    function testCancelProposal() public {
        testSecondPayment();
        vm.startPrank(alex);
        c_ProposalManager.cancelProposal(0);
        vm.stopPrank();

        uint256 alexBalance = IERC20(usdcToken).balanceOf(alex);
        uint256 proposalBalance = c_Escrow.proposalBalances(0);
        console.log("alex :", alex);
        console.log("prop bal :", proposalBalance);
        assertEq(alexBalance, 2100000);
    }

    function testPlaceBid() public {
        vm.startPrank(0x30217A8C17EF5571639948D118D086c73f823058);

        ProposalManager pm = ProposalManager(
            0x9e002323F46D6908EC4ef5444f1Bd0F67AF9Cf10
        );
        Proposal memory proposal = pm.getProposal(32);
        console.log("proposal state", proposal.state);
        console.log("bidder", proposal.bidder);
        console.log("client", proposal.client);
        console.log("bid amount :", proposal.bidAmount);
        console.log("bidget :", proposal.budget);
        // pm.createProposal(proposal.startTime + , 10000000);
        // pm.acceptBid(0,0x30217A8C17EF5571639948D118D086c73f823058 , 1000000);
        pm.paySecondMilestone(32);

        vm.stopPrank();
    }

    function testFirstMileStone() public {
        vm.startPrank(0x30217A8C17EF5571639948D118D086c73f823058);

        // ProposalManager pm = ProposalManager(0x9e002323F46D6908EC4ef5444f1Bd0F67AF9Cf10);
        Escrow esc = Escrow(0xb7eBD3c77C8c0B0Cf783b7C8930C01BCDf8c562C);
        address govenrance = esc.governanceContract();
        address owner = esc.owner();
        console.log("owner address ", owner);
        console.log("governance :", govenrance);
        // pm.payFirstMilestone(0);
        vm.stopPrank();
    }

    function testOpenProposalToBidFork() public {
        vm.startPrank(0x30217A8C17EF5571639948D118D086c73f823058);
        ProposalManager pm = ProposalManager(
            0x9e002323F46D6908EC4ef5444f1Bd0F67AF9Cf10
        );
        // pm.cancelProposal(25);
        Proposal memory proposal = pm.getProposal(25);
        console.log("proposal state", proposal.state);
        vm.stopPrank();
    }

    function testPayInstant() public {
        vm.startPrank(0x30217A8C17EF5571639948D118D086c73f823058);
        ProposalManager pm = ProposalManager(
            0x9e002323F46D6908EC4ef5444f1Bd0F67AF9Cf10
        );
        // pm.cancelProposal(25);
        Proposal memory proposal = pm.getProposal(44);
        console.log("proposal bid amount :",proposal.bidAmount);
        pm.payFirstMilestone(44);
        vm.stopPrank();
    }


    function testDeposit() public {
        vm.startPrank(0x30217A8C17EF5571639948D118D086c73f823058);
        ProposalManager pm = ProposalManager(
            0x9e002323F46D6908EC4ef5444f1Bd0F67AF9Cf10
        );
        // pm.cancelProposal(25);
        Proposal memory proposal = pm.getProposal(44);
        console.log("proposal bid amount :",proposal.bidAmount);
        IERC20(0x036CbD53842c5426634e7929541eC2318f3dCF7e).approve(0x9e002323F46D6908EC4ef5444f1Bd0F67AF9Cf10, 1000000);
        pm.depositBidAmount(49);
        vm.stopPrank();
    }

    //   function testTreasureBalance() public view {
    //     // Make sure you're using the correct Treasury instance
    //     Treasury treasury = Treasury(0x988ABc52D200bF476885262f82a3a5A1a4e2A2de);

    //     // Check USDC token address
    //     address usdcAddress = treasury.usdcTokenAddress();
    //     console.log("USDC Address:", usdcAddress);

    //     // Get balance
    //     uint256 balance = treasury.getTotalTreasureBalance();
    //     console.log("Balance:", balance);

    //     assertTrue(balance >= 0, "Balance should be >= 0");
    // }
    modifier createProposal() {
        vm.startPrank(alex);
        c_ProposalManager.createProposal(10 days, 10 * 1e6);
        vm.stopPrank();
        _;
    }
}
