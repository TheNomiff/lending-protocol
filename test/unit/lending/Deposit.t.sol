// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Lending} from "../../../src/Lending.sol";
import {LendingTestBase} from "../../utils/LendingTestBase.t.sol";

contract DepositTest is LendingTestBase {
    function testDepositSuccess() public {
        uint256 depositAmount = 10 ether;

        _depositAs(USER, depositAmount);
        (uint256 depositedAmount,,) = _userPosition(USER, ETH_SENTINEL);

        (,, uint256 totalLiquidity,,) = lending.reserves(ETH_SENTINEL);

        assertEq(depositedAmount, depositAmount);
        assertEq(totalLiquidity, depositAmount);
    }

    function testDepositRevertsIfAmountZero() public {
        vm.prank(USER);
        vm.expectRevert(Lending.Lending__AmountZero.selector);
        lending.deposit{value: 0}(ETH_SENTINEL);
    }

    function testMultipleUsersCanDeposit() public {
        uint256 depositAmount = 10 ether;

        _depositAs(USER, depositAmount);
        _depositAs(USER_A, depositAmount);
        _depositAs(USER_B, depositAmount);

        (,, uint256 totalLiquidity,,) = lending.reserves(ETH_SENTINEL);

        assertEq(lending.getBalance(USER, ETH_SENTINEL), depositAmount);
        assertEq(lending.getBalance(USER_A, ETH_SENTINEL), depositAmount);
        assertEq(lending.getBalance(USER_B, ETH_SENTINEL), depositAmount);
        assertEq(totalLiquidity, depositAmount * 3);
    }
}
