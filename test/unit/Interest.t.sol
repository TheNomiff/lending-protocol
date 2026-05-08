// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Landing} from "../../src/Landing.sol";
import {LandingTestBase} from "../utils/LandingTestBase.t.sol";

contract InterestTest is LandingTestBase {
    function testInterestAccruesOverTime() public {
        _openPosition(USER, 10 ether, 5 ether);
        skip(1 days);

        uint256 totalDebt = landing.getTotalDebt(USER);
        (, uint256 totalBorrow, ) = _userPosition(USER);
        assertGt(totalDebt, totalBorrow);
    }

    function testBorrowRevertsAfterInterestAccrual() public {
        _openPosition(USER, 10 ether, 5 ether);
        skip(10 days);

        uint256 debt = landing.getTotalDebt(USER);
        uint256 collateral = landing.getBalance(USER);
        assertGt(debt, collateral / 2);

        vm.prank(USER);
        vm.expectRevert(Landing.Landing__BorrowExceedsCollateral.selector);
        landing.borrow(5 ether);
    }

    function testWithdrawRevertsAfterInterestAccrual() public {
        _openPosition(USER, 10 ether, 5 ether);
        skip(10 days);

        uint256 debt = landing.getTotalDebt(USER);
        uint256 collateral = landing.getBalance(USER);
        assertGt(debt, collateral / 2);

        vm.prank(USER);
        vm.expectRevert(Landing.Landing__BorrowExceedsCollateral.selector);
        landing.withdraw(5 ether);
    }

    function testRepayIncludesAccruedInterest() public {
        _openPosition(USER, 50 ether, 5 ether);
        skip(1 days);

        uint256 amountRepay = landing.getTotalDebt(USER);
        _repayAs(USER, amountRepay);

        (, uint256 totalBorrow, ) = _userPosition(USER);
        assertEq(totalBorrow, 0);
        assertEq(landing.getTotalDebt(USER), 0);
    }

    function testAccrueInterestDoesNotDoubleCount() public {
        _openPosition(USER, 50 ether, 5 ether);
        skip(1 days);

        _repayAs(USER, 2 ether);
        uint256 debtAfterFirst = landing.getTotalDebt(USER);

        skip(1 days);
        uint256 debtAfterSecond = landing.getTotalDebt(USER);
        assertGt(debtAfterSecond, debtAfterFirst);
    }

    function testInterestAfterLongDuration() public {
        _openPosition(USER, 10 ether, 5 ether);
        skip(365 days);

        uint256 expectedDebt = 5.25 ether;
        uint256 liveDebt = landing.getTotalDebt(USER);
        assertApproxEqAbs(liveDebt, expectedDebt, 1e16);
    }

    function testInterestAlwaysIncreasesOverTime() public {
        _openPosition(USER, 50 ether, 5 ether);

        skip(1 days);
        uint256 t1 = landing.getTotalDebt(USER);

        skip(1 days);
        uint256 t2 = landing.getTotalDebt(USER);

        skip(1 days);
        uint256 t3 = landing.getTotalDebt(USER);

        assertGt(t2, t1);
        assertGt(t3, t2);
    }
}
