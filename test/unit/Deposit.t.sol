// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Lending} from "../../src/Lending.sol";
import {LendingTestBase} from "../utils/LendingTestBase.t.sol";

contract DepositTest is LendingTestBase {
    function testDepositSuccess() public {
        uint256 depositAmount = 10 ether;

        _depositAs(USER, depositAmount);
        (uint256 depositedAmount,,) = _userPosition(USER);

        assertEq(depositedAmount, depositAmount);
        assertEq(lending.totalLiquidity(), depositAmount);
    }

    function testDepositRevertsIfAmountZero() public {
        vm.prank(USER);
        vm.expectRevert(Lending.Lending__AmountZero.selector);
        lending.deposit{value: 0}();
    }

    function testMultipleUsersCanDeposit() public {
        uint256 depositAmount = 10 ether;

        _depositAs(USER, depositAmount);
        _depositAs(USER_A, depositAmount);
        _depositAs(USER_B, depositAmount);

        assertEq(lending.getBalance(USER), depositAmount);
        assertEq(lending.getBalance(USER_A), depositAmount);
        assertEq(lending.getBalance(USER_B), depositAmount);
        assertEq(lending.totalLiquidity(), depositAmount * 3);
    }
}
