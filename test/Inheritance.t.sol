// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Inheritance} from "../src/Inheritance.sol";

contract InheritanceTest is Test {
    Inheritance public inheritance;
    address payable public owner;
    address public heir;
    address public newHeir;

    uint256 constant INACTIVITY_PERIOD = 30 days;

    event Deposited(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);
    event HeirUpdated(address indexed previousHeir, address indexed newHeir);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        owner = payable(makeAddr("owner"));
        heir = makeAddr("heir");
        newHeir = makeAddr("newHeir");

        vm.deal(owner, 100 ether);

        vm.prank(owner);
        inheritance = new Inheritance(heir);

        vm.deal(address(inheritance), 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(inheritance.owner(), owner);
        assertEq(inheritance.heir(), heir);
        assertEq(inheritance.lastWithdrawal(), block.timestamp);
        assertEq(inheritance.INACTIVITY_PERIOD(), 30 days);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanWithdraw() public {
        uint256 balanceBefore = owner.balance;
        uint256 contractBalanceBefore = address(inheritance).balance;

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(owner, 1 ether);
        inheritance.withdraw(1 ether);

        assertEq(owner.balance, balanceBefore + 1 ether);
        assertEq(address(inheritance).balance, contractBalanceBefore - 1 ether);
        assertEq(inheritance.lastWithdrawal(), block.timestamp);
    }

    function test_OwnerCanWithdrawZeroToResetTimer() public {
        vm.warp(block.timestamp + 15 days);
        uint256 lastWithdrawalBefore = inheritance.lastWithdrawal();

        vm.prank(owner);
        inheritance.withdraw(0);

        assertGt(inheritance.lastWithdrawal(), lastWithdrawalBefore);
        assertEq(inheritance.lastWithdrawal(), block.timestamp);
    }

    function test_WithdrawRevertsIfNotOwner() public {
        vm.prank(heir);
        vm.expectRevert(Inheritance.OnlyOwner.selector);
        inheritance.withdraw(1 ether);
    }

    function test_WithdrawRevertsIfInsufficientBalance() public {
        vm.prank(owner);
        vm.expectRevert(Inheritance.InsufficientBalance.selector);
        inheritance.withdraw(100 ether);
    }

    function test_WithdrawAllBalance() public {
        uint256 contractBalance = address(inheritance).balance;

        vm.prank(owner);
        inheritance.withdraw(contractBalance);

        assertEq(address(inheritance).balance, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            SET HEIR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanSetNewHeir() public {
        uint256 lastWithdrawalBefore = inheritance.lastWithdrawal();

        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit HeirUpdated(heir, newHeir);
        inheritance.setHeir(newHeir);

        assertEq(inheritance.heir(), newHeir);
        // Verify timer was NOT reset
        assertEq(inheritance.lastWithdrawal(), lastWithdrawalBefore);
    }

    function test_SetHeirRevertsIfNotOwner() public {
        vm.prank(heir);
        vm.expectRevert(Inheritance.OnlyOwner.selector);
        inheritance.setHeir(newHeir);
    }

    function test_SetHeirRevertsIfZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(Inheritance.InvalidHeirAddress.selector);
        inheritance.setHeir(address(0));
    }

    function test_SetHeirRevertsIfOwnerIsHeir() public {
        vm.prank(owner);
        vm.expectRevert(Inheritance.InvalidHeirAddress.selector);
        inheritance.setHeir(owner);
    }

    function test_SetHeirDoesNotResetTimer() public {
        vm.warp(block.timestamp + 15 days);
        uint256 lastWithdrawalBefore = inheritance.lastWithdrawal();

        vm.prank(owner);
        inheritance.setHeir(newHeir);

        // Setting heir should NOT reset the timer
        assertEq(inheritance.lastWithdrawal(), lastWithdrawalBefore);
    }

    function test_HeirCanClaimEvenIfOwnerSetsHeir() public {
        // Owner sets new heir at day 20
        vm.warp(block.timestamp + 20 days);
        vm.prank(owner);
        inheritance.setHeir(newHeir);

        // Move to day 31 (31 days since last withdrawal)
        vm.warp(block.timestamp + 11 days);

        // NEW heir should be able to claim since no withdrawal happened for 31 days
        vm.prank(newHeir);
        inheritance.claimOwnership(makeAddr("thirdHeir"));

        assertEq(inheritance.owner(), newHeir);
    }

    /*//////////////////////////////////////////////////////////////
                        CLAIM OWNERSHIP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_HeirCanClaimAfterInactivity() public {
        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);

        vm.prank(heir);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, heir);
        inheritance.claimOwnership(newHeir);

        assertEq(inheritance.owner(), heir);
        assertEq(inheritance.heir(), newHeir);
        assertEq(inheritance.lastWithdrawal(), block.timestamp);
    }

    function test_ClaimOwnershipRevertsIfNotHeir() public {
        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);

        vm.prank(owner);
        vm.expectRevert(Inheritance.OnlyHeir.selector);
        inheritance.claimOwnership(newHeir);
    }

    function test_ClaimOwnershipRevertsIfOwnerStillActive() public {
        vm.warp(block.timestamp + 29 days);

        vm.prank(heir);
        vm.expectRevert(Inheritance.OwnerStillActive.selector);
        inheritance.claimOwnership(newHeir);
    }

    function test_ClaimOwnershipExactlyAt30Days() public {
        vm.warp(block.timestamp + INACTIVITY_PERIOD);

        vm.prank(heir);
        inheritance.claimOwnership(newHeir);

        assertEq(inheritance.owner(), heir);
    }

    function test_HeirCannotSetSelfAsNewHeir() public {
        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);

        vm.prank(heir);
        vm.expectRevert(Inheritance.InvalidHeirAddress.selector);
        inheritance.claimOwnership(heir);
    }

    function test_HeirCannotSetZeroAddress() public {
        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);

        vm.prank(heir);
        vm.expectRevert(Inheritance.InvalidHeirAddress.selector);
        inheritance.claimOwnership(address(0));
    }

    function test_NewOwnerCanSetNewHeir() public {
        address thirdHeir = makeAddr("thirdHeir");

        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);
        vm.prank(heir);
        inheritance.claimOwnership(newHeir);

        vm.prank(heir);
        inheritance.setHeir(thirdHeir);

        assertEq(inheritance.heir(), thirdHeir);
    }

    function test_InheritanceChain() public {
        address thirdHeir = makeAddr("thirdHeir");

        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);
        vm.prank(heir);
        inheritance.claimOwnership(newHeir);

        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);
        vm.prank(newHeir);
        inheritance.claimOwnership(thirdHeir);

        assertEq(inheritance.owner(), newHeir);
        assertEq(inheritance.heir(), thirdHeir);
    }

    /*//////////////////////////////////////////////////////////////
                        RECEIVE & FALLBACK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ReceiveEther() public {
        uint256 balanceBefore = address(inheritance).balance;

        (bool success,) = address(inheritance).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(address(inheritance).balance, balanceBefore + 1 ether);
    }

    function test_FallbackWithEther() public {
        uint256 balanceBefore = address(inheritance).balance;

        (bool success,) = address(inheritance).call{value: 1 ether}("randomData");
        assertTrue(success);
        assertEq(address(inheritance).balance, balanceBefore + 1 ether);
    }

    function test_FallbackWithoutEtherReverts() public {
        (bool success,) = address(inheritance).call("randomData");
        assertFalse(success);
    }

    /*//////////////////////////////////////////////////////////////
                        COMPLEX SCENARIO TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OwnerActivityResetsTimer() public {
        vm.warp(block.timestamp + 20 days);

        vm.prank(owner);
        inheritance.withdraw(0);

        vm.warp(block.timestamp + 29 days);

        vm.prank(heir);
        vm.expectRevert(Inheritance.OwnerStillActive.selector);
        inheritance.claimOwnership(newHeir);
    }

    function test_MultipleWithdrawals() public {
        uint256 contractBalance = address(inheritance).balance;

        vm.startPrank(owner);
        inheritance.withdraw(1 ether);
        inheritance.withdraw(2 ether);
        inheritance.withdraw(3 ether);
        vm.stopPrank();

        assertEq(address(inheritance).balance, contractBalance - 6 ether);
    }

    function test_HeirCannotWithdrawBeforeClaiming() public {
        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);

        vm.prank(heir);
        vm.expectRevert(Inheritance.OnlyOwner.selector);
        inheritance.withdraw(1 ether);
    }

    function test_HeirCanWithdrawAfterClaiming() public {
        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);

        vm.prank(heir);
        inheritance.claimOwnership(newHeir);

        uint256 balanceBefore = heir.balance;
        vm.prank(heir);
        inheritance.withdraw(1 ether);

        assertEq(heir.balance, balanceBefore + 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_WithdrawAmount(uint256 amount) public {
        amount = bound(amount, 0, address(inheritance).balance);

        vm.prank(owner);
        inheritance.withdraw(amount);

        assertEq(inheritance.lastWithdrawal(), block.timestamp);
    }

    function testFuzz_CannotClaimBeforeInactivityPeriod(uint256 timeElapsed) public {
        timeElapsed = bound(timeElapsed, 0, INACTIVITY_PERIOD - 1);

        vm.warp(block.timestamp + timeElapsed);

        vm.prank(heir);
        vm.expectRevert(Inheritance.OwnerStillActive.selector);
        inheritance.claimOwnership(newHeir);
    }

    function testFuzz_CanClaimAfterInactivityPeriod(uint256 timeElapsed) public {
        timeElapsed = bound(timeElapsed, INACTIVITY_PERIOD, 365 days);

        vm.warp(block.timestamp + timeElapsed);

        vm.prank(heir);
        inheritance.claimOwnership(newHeir);

        assertEq(inheritance.owner(), heir);
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetBalance() public view {
        assertEq(inheritance.getBalance(), 10 ether);
    }

    function test_GetTimeUntilClaimable() public {
        uint256 timeRemaining = inheritance.getTimeUntilClaimable();
        assertEq(timeRemaining, INACTIVITY_PERIOD);

        vm.warp(block.timestamp + 15 days);
        timeRemaining = inheritance.getTimeUntilClaimable();
        assertEq(timeRemaining, 15 days);

        vm.warp(block.timestamp + INACTIVITY_PERIOD);
        timeRemaining = inheritance.getTimeUntilClaimable();
        assertEq(timeRemaining, 0);
    }

    function test_CanHeirClaim() public {
        assertFalse(inheritance.canHeirClaim());

        vm.warp(block.timestamp + 29 days);
        assertFalse(inheritance.canHeirClaim());

        vm.warp(block.timestamp + INACTIVITY_PERIOD);
        assertTrue(inheritance.canHeirClaim());
    }

    function test_DepositedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit Deposited(address(this), 1 ether);
        (bool success,) = address(inheritance).call{value: 1 ether}("");
        assertTrue(success);
    }
}

