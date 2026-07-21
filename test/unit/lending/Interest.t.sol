// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Lending} from "../../../src/Lending.sol";
import {LendingTestBase} from "../../utils/LendingTestBase.t.sol";

contract InterestTest is LendingTestBase {
    function testInterestAccruesOverTime() public {
        _openPosition(USER, 10 ether, 5 ether);
        skip(1 days);

        uint256 totalDebt = lending.getTotalDebt(USER, ETH_SENTINEL);
        (, uint256 totalBorrow,) = _userPosition(USER, ETH_SENTINEL);
        assertGt(totalDebt, totalBorrow);
    }

    function testBorrowRevertsAfterInterestAccrual() public {
        _openPosition(USER, 10 ether, 5 ether);
        skip(10 days);

        uint256 debt = lending.getTotalDebt(USER, ETH_SENTINEL);
        uint256 collateral = lending.getBalance(USER, ETH_SENTINEL);
        assertGt(debt, collateral / 2);

        vm.prank(USER, ETH_SENTINEL);
        vm.expectRevert(Lending.Lending__BorrowExceedsCollateral.selector);
        lending.borrow(5 ether, ETH_SENTINEL);
    }

    function testWithdrawRevertsAfterInterestAccrual() public {
        _openPosition(USER, 10 ether, 5 ether);
        skip(10 days);

        uint256 debt = lending.getTotalDebt(USER, ETH_SENTINEL);
        uint256 collateral = lending.getBalance(USER, ETH_SENTINEL);
        assertGt(debt, collateral / 2);

        vm.prank(USER, ETH_SENTINEL);
        vm.expectRevert(Lending.Lending__BorrowExceedsCollateral.selector);
        lending.withdraw(5 ether, ETH_SENTINEL);
    }

    function testRepayIncludesAccruedInterest() public {
        _openPosition(USER, 50 ether, 5 ether);
        skip(1 days);

        uint256 amountRepay = lending.getTotalDebt(USER, ETH_SENTINEL);
        _repayAs(USER, amountRepay);

        (, uint256 totalBorrow,) = _userPosition(USER, ETH_SENTINEL);
        assertEq(totalBorrow, 0);
        assertEq(lending.getTotalDebt(USER, ETH_SENTINEL), 0);
    }

    function testAccrueInterestDoesNotDoubleCount() public {
        _openPosition(USER, 50 ether, 5 ether);
        skip(1 days);

        _repayAs(USER, 2 ether);
        uint256 debtAfterFirst = lending.getTotalDebt(USER, ETH_SENTINEL);

        skip(1 days);
        uint256 debtAfterSecond = lending.getTotalDebt(USER, ETH_SENTINEL);
        assertGt(debtAfterSecond, debtAfterFirst);
    }

    function testInterestAfterLongDuration() public {
        _openPosition(USER, 10 ether, 5 ether);
        skip(365 days);

        uint256 expectedDebt = 5.25 ether;
        uint256 liveDebt = lending.getTotalDebt(USER, ETH_SENTINEL);
        assertApproxEqAbs(liveDebt, expectedDebt, 1e16);
    }

    function testInterestAlwaysIncreasesOverTime() public {
        _openPosition(USER, 50 ether, 5 ether);

        skip(1 days);
        uint256 t1 = lending.getTotalDebt(USER, ETH_SENTINEL);

        skip(1 days);
        uint256 t2 = lending.getTotalDebt(USER, ETH_SENTINEL);

        skip(1 days);
        uint256 t3 = lending.getTotalDebt(USER, ETH_SENTINEL);

        assertGt(t2, t1);
        assertGt(t3, t2);
    }
}
