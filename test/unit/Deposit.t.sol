// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Landing} from "../../src/Landing.sol";
import {LandingTestBase} from "../utils/LandingTestBase.t.sol";

contract DepositTest is LandingTestBase {
    function testDepositSuccess() public {
        uint256 depositAmount = 10 ether;

        _depositAs(USER, depositAmount);
        (uint256 depositedAmount,,) = _userPosition(USER);

        assertEq(depositedAmount, depositAmount);
        assertEq(landing.totalLiquidity(), depositAmount);
    }

    function testDepositRevertsIfAmountZero() public {
        vm.prank(USER);
        vm.expectRevert(Landing.Landing__AmountZero.selector);
        landing.deposit{value: 0}();
    }

    function testMultipleUsersCanDeposit() public {
        uint256 depositAmount = 10 ether;

        _depositAs(USER, depositAmount);
        _depositAs(USER_A, depositAmount);
        _depositAs(USER_B, depositAmount);

        assertEq(landing.getBalance(USER), depositAmount);
        assertEq(landing.getBalance(USER_A), depositAmount);
        assertEq(landing.getBalance(USER_B), depositAmount);
        assertEq(landing.totalLiquidity(), depositAmount * 3);
    }
}
