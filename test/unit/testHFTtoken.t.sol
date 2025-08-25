// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {HFTtoken} from "../../src/HFTtoken.sol";
import {IHFTtoken} from "../../src/interfaces/IHFTtoken.sol";

contract TestHFTtoken is Test {
    HFTtoken token;
    address deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address alex = makeAddr("alex");
    address bob = makeAddr("star");

    function setUp() public {
        token = new HFTtoken(deployer, 0x036CbD53842c5426634e7929541eC2318f3dCF7e);
    }

    function testOwner() external view {
        assertEq(token.owner(), deployer);
    }

    function testClaimTokens() external {
        vm.startPrank(alex);
        token.claimTokens();
        uint256 balanceOfAlex = token.balanceOf(alex);
        console.log(balanceOfAlex);
        assertEq(balanceOfAlex, 150 * 1e18);
        vm.stopPrank();
    }

    function testMultipleClaims() external {
        vm.startPrank(alex);
        token.claimTokens();
        uint256 balanceOfAlex = token.balanceOf(alex);
        console.log(balanceOfAlex);
        assertEq(balanceOfAlex, 150 * 1e18);

        // Corrected: expectRevert -> expectRevert
        vm.expectRevert(HFTtoken.HFTtoken__canClaimOnlyOnceInAMonth.selector);
        token.claimTokens();
        vm.stopPrank();
    }

    function testClaimAfter30Days() external {
        vm.startPrank(alex);
        token.claimTokens();

        // claim after 30 days
        uint256 targetTime = block.timestamp + 30 days;
        vm.warp(targetTime);
        assertEq(block.timestamp, targetTime);
        // token.claimTokens();
        token.claimTokens();
        uint256 netTokens = token.balanceOf(alex);
        assertEq(netTokens, 300 * 1e18);
        vm.stopPrank();
    }

    // function testTransferTokens() external claimTokens {
    //     // 1. Alex approves Bob to spend 1 token
    //     vm.startPrank(alex);
    //     token.approve(bob, 1 * 1e18);
    //     vm.stopPrank();

    //     // 2. Check allowance (optional)
    //     uint256 allowanceGiven = token.allowance(alex, bob);
    //     console.log("Allowance given:", allowanceGiven);
    //     assertEq(allowanceGiven, 1 * 1e18); // Should pass

    //     // 3. Bob transfers from Alex to Bob
    //     vm.prank(bob); // Switch to Bob's account
    //     token.transferFrom(alex, bob, 1 * 1e18); // Now this should work

    //     // 4. Verify tokens were moved
    //     assertEq(token.balanceOf(bob), 1 * 1e18);
    // }

    function testTokenTransferAfterTransferEnables() external claimTokens {
        vm.startPrank(deployer);
        token.enableTransfers(true);
        vm.stopPrank();

        vm.startPrank(alex);
        token.approve(bob, 1 * 1e18);
        vm.stopPrank();

        vm.startPrank(bob);
        token.transferFrom(alex, bob, 1 * 1e18);
        vm.stopPrank();
    }

    function testPlaceBidByHFT() public {
        vm.startPrank(0x30217A8C17EF5571639948D118D086c73f823058);
        HFTtoken tokenOne = HFTtoken(0xd0D1B6E1dE2F705701FE370e91f8fb4731161d5a);
        tokenOne.placeBid(1);
        vm.stopPrank();
    }

    modifier claimTokens() {
        vm.startPrank(alex);
        token.claimTokens();
        vm.stopPrank();
        _;
    }
}
