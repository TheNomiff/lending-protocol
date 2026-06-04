// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Lending} from "../../src/Lending.sol";
import {LendingTestBase} from "../utils/LendingTestBase.t.sol";

contract HealthFactorTest is LendingTestBase {
    function testHealthFactorIsMaxWhenNoDebt() public {
        _depositAs(USER, 10 ether);
        assertEq(lending.getHealthFactor(USER), type(uint256).max);
    }

    function testHealthFactorDropsAfterBorrow() public {
        _depositAs(USER, 10 ether);
        uint256 hfBeforeBorrow = lending.getHealthFactor(USER);

        _borrowAs(USER, 4 ether);
        uint256 hfAfterBorrow = lending.getHealthFactor(USER);

        assertGt(hfBeforeBorrow, hfAfterBorrow);
        assertGe(hfAfterBorrow, 1e18);
    }

    function testHealthFactorDropsAsInterestAccrues() public {
        _openPosition(USER, 10 ether, 4 ether);
        uint256 hfBefore = lending.getHealthFactor(USER);

        skip(30 days);
        uint256 hfAfter = lending.getHealthFactor(USER);

        assertGt(hfBefore, hfAfter);
    }

    function testWithdrawRevertsWhenHealthFactorWouldBreak() public {
        _openPosition(USER, 10 ether, 5 ether);

        vm.prank(USER);
        vm.expectRevert(Lending.Lending__BorrowExceedsCollateral.selector);
        lending.withdraw(1 ether);
    }
}
