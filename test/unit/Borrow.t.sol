// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Landing} from "../../src/Landing.sol";
import {LandingTestBase} from "../utils/LandingTestBase.t.sol";

contract BorrowTest is LandingTestBase {
    function testBorrowSuccess() public {
        uint256 amountDeposit = 10 ether;
        uint256 amountBorrow = 5 ether;

        _openPosition(USER, amountDeposit, amountBorrow);
        (uint256 depositedAmount, uint256 borrowedAmount, ) = _userPosition(USER);

        assertEq(borrowedAmount, amountBorrow);
        assertEq(depositedAmount, amountDeposit);
        assertEq(landing.totalLiquidity(), amountDeposit - amountBorrow);
    }

    function testBorrowRevertsIfCollateralBreaks() public {
        _depositAs(USER, 10 ether);

        vm.prank(USER);
        vm.expectRevert(Landing.Landing__BorrowExceedsCollateral.selector);
        landing.borrow(10 ether);
    }

    function testBorrowRevertsIfNotEnoughLiquidity() public {
        _depositAs(USER, 1 ether);

        vm.prank(USER);
        vm.expectRevert(Landing.Landing__BorrowExceedsCollateral.selector);
        landing.borrow(2 ether);
    }

    function testBorrowRevertsIfAmountZero() public {
        vm.prank(USER);
        vm.expectRevert(Landing.Landing__AmountZero.selector);
        landing.borrow(0);
    }
}
