// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { Test, console2 } from "forge-std/Test.sol";

import { IRebaseToken } from "../src/interfaces/IRebaseToken.sol";
import { RebaseToken } from "../src/RebaseToken.sol";
import { Vault } from "../src/Vault.sol";
import { Deposit, Redeem, InterestRateSet } from "../src/Events.sol";
import { RebaseToken__NewInterestRateCannotBeGreaterThanPrevious } from "../src/Errors.sol";

contract VaultAndRebaseTokenTest is Test {
    RebaseToken rebaseToken;
    Vault vault;

    uint256 public initialInterestRate = 5e10;

    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() external {
        vm.startPrank(owner);

        rebaseToken = new RebaseToken(initialInterestRate);
        vault = new Vault(IRebaseToken(address(rebaseToken)));

        rebaseToken.grantMinterAndBurnerRole(address(vault));

        vm.stopPrank();
    }

    function testInterestRateModificationByOwner(uint256 newInterestRate) external {
        newInterestRate = bound(newInterestRate, 1, initialInterestRate - 1);

        vm.startPrank(owner);
        vm.expectEmit(address(rebaseToken));
        emit InterestRateSet(newInterestRate);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testInterestRateCannotBeGreaterThanPrevious(uint256 newInterestRate) external {
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint256).max);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                RebaseToken__NewInterestRateCannotBeGreaterThanPrevious.selector,
                newInterestRate,
                initialInterestRate
            )
        );
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testUserCanDepositAndRedeem(uint256 amountToDeposit, uint256 amountToWithdraw)
        external
    {
        amountToDeposit = bound(amountToDeposit, 1, type(uint32).max);
        amountToWithdraw = bound(amountToWithdraw, 1, amountToDeposit);

        vm.deal(user1, amountToDeposit);

        vm.startPrank(user1);

        vm.expectEmit(address(vault));
        emit Deposit(user1, amountToDeposit);
        vault.deposit{ value: amountToDeposit }();

        assertEq(rebaseToken.principalBalance(user1), amountToDeposit);
        assertEq(rebaseToken.balanceOf(user1), amountToDeposit);
        assertEq(user1.balance, 0);
        assertEq(rebaseToken.getUserInterestRate(user1), initialInterestRate);

        vm.expectEmit(address(vault));
        emit Redeem(user1, amountToWithdraw);
        vault.redeem(amountToWithdraw);

        vm.stopPrank();

        assertEq(rebaseToken.principalBalance(user1), amountToDeposit - amountToWithdraw);
        assertEq(rebaseToken.balanceOf(user1), amountToDeposit - amountToWithdraw);
        assertEq(user1.balance, amountToWithdraw);
        assertEq(rebaseToken.getUserInterestRate(user1), initialInterestRate);
    }

    function testInterestAccrual(uint256 amountToDeposit, uint256 time) external {
        amountToDeposit = bound(amountToDeposit, 1, type(uint32).max);
        time = bound(time, 1000, type(uint64).max);

        vm.deal(user1, amountToDeposit);

        vm.prank(user1);

        vm.expectEmit(address(vault));
        emit Deposit(user1, amountToDeposit);
        vault.deposit{ value: amountToDeposit }();

        assertEq(rebaseToken.principalBalance(user1), amountToDeposit);
        assertEq(rebaseToken.balanceOf(user1), amountToDeposit);
        assertEq(user1.balance, 0);
        assertEq(rebaseToken.getUserInterestRate(user1), initialInterestRate);

        vm.warp(vm.getBlockTimestamp() + time);

        uint256 newBalanceWithInterestAccrued = rebaseToken.balanceOf(user1);
        assertGe(newBalanceWithInterestAccrued, amountToDeposit);

        vm.deal(owner, newBalanceWithInterestAccrued);
        vm.prank(owner);
        address(vault).call{ value: newBalanceWithInterestAccrued }("");

        vm.prank(user1);

        vm.expectEmit(address(vault));
        emit Redeem(user1, newBalanceWithInterestAccrued);
        vault.redeem(newBalanceWithInterestAccrued);

        assertEq(rebaseToken.principalBalance(user1), 0);
        assertEq(rebaseToken.balanceOf(user1), 0);
        assertEq(user1.balance, newBalanceWithInterestAccrued);
    }

    function testTransfer(uint256 amountToDeposit, uint256 time, uint256 amountToTransfer)
        external
    {
        amountToDeposit = bound(amountToDeposit, 1, type(uint32).max);
        amountToTransfer = bound(amountToTransfer, 1, amountToDeposit);

        time = bound(time, 1000, type(uint64).max);

        vm.deal(user1, amountToDeposit);

        vm.prank(user1);

        vm.expectEmit(address(vault));
        emit Deposit(user1, amountToDeposit);
        vault.deposit{ value: amountToDeposit }();

        assertEq(rebaseToken.principalBalance(user1), amountToDeposit);
        assertEq(rebaseToken.balanceOf(user1), amountToDeposit);
        assertEq(user1.balance, 0);
        assertEq(rebaseToken.getUserInterestRate(user1), initialInterestRate);

        vm.warp(vm.getBlockTimestamp() + time);

        uint256 newBalanceWithInterestAccrued = rebaseToken.balanceOf(user1);
        assertGe(newBalanceWithInterestAccrued, amountToDeposit);

        vm.deal(owner, newBalanceWithInterestAccrued);
        vm.prank(owner);
        address(vault).call{ value: newBalanceWithInterestAccrued }("");

        uint256 user1BalanceBeforeTransfer = rebaseToken.balanceOf(user1);

        vm.prank(user1);
        rebaseToken.transfer(user2, amountToTransfer);
        assertEq(rebaseToken.getUserInterestRate(user2), rebaseToken.getUserInterestRate(user1));
        assertEq(rebaseToken.balanceOf(user2), amountToTransfer);
        assertEq(rebaseToken.balanceOf(user1), user1BalanceBeforeTransfer - amountToTransfer);

        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        vm.warp(vm.getBlockTimestamp() + time);

        uint256 user2NewBalanceWithInterestAccrued = rebaseToken.balanceOf(user2);
        assertGe(user2NewBalanceWithInterestAccrued, amountToTransfer);

        vm.deal(owner, user2NewBalanceWithInterestAccrued);
        vm.prank(owner);
        address(vault).call{ value: user2NewBalanceWithInterestAccrued }("");

        vm.prank(user2);
        rebaseToken.transfer(user1, user2NewBalanceWithInterestAccrued);
        assertEq(rebaseToken.getUserInterestRate(user1), initialInterestRate);
        assertEq(rebaseToken.balanceOf(user2), 0);
    }

    function testDeploy() external view {
        assertNotEq(address(rebaseToken), address(0));
        assertNotEq(address(vault), address(0));
        assertEq(address(vault.getRebaseToken()), address(rebaseToken));
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }
}
