// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Landing} from "../../src/Landing.sol";
import {LandingTestBase} from "../utils/LandingTestBase.t.sol";

contract HealthFactorTest is LandingTestBase {
    function testHealthFactorIsMaxWhenNoDebt() public {
        _depositAs(USER, 10 ether);
        assertEq(landing.getHealthFactor(USER), type(uint256).max);
    }

    function testHealthFactorDropsAfterBorrow() public {
        _depositAs(USER, 10 ether);
        uint256 hfBeforeBorrow = landing.getHealthFactor(USER);

        _borrowAs(USER, 4 ether);
        uint256 hfAfterBorrow = landing.getHealthFactor(USER);

        assertGt(hfBeforeBorrow, hfAfterBorrow);
        assertGe(hfAfterBorrow, 1e18);
    }

    function testHealthFactorDropsAsInterestAccrues() public {
        _openPosition(USER, 10 ether, 4 ether);
        uint256 hfBefore = landing.getHealthFactor(USER);

        skip(30 days);
        uint256 hfAfter = landing.getHealthFactor(USER);

        assertGt(hfBefore, hfAfter);
    }

    function testWithdrawRevertsWhenHealthFactorWouldBreak() public {
        _openPosition(USER, 10 ether, 5 ether);

        vm.prank(USER);
        vm.expectRevert(Landing.Landing__BorrowExceedsCollateral.selector);
        landing.withdraw(1 ether);
    }
}
