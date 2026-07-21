// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Lending} from "../../../src/Lending.sol";
import {LendingTestBase} from "../../utils/LendingTestBase.t.sol";

contract BorrowTest is LendingTestBase {
    function testBorrowSuccess() public {
        uint256 amountDeposit = 10 ether;
        uint256 amountBorrow = 5 ether;

        _openPosition(USER, amountDeposit, amountBorrow);
        (uint256 depositedAmount, uint256 borrowedAmount,) = _userPosition(USER, ETH_SENTINEL);

        (,, uint256 totalLiquidity,,) = lending.reserves(ETH_SENTINEL);

        assertEq(borrowedAmount, amountBorrow);
        assertEq(depositedAmount, amountDeposit);
        assertEq(totalLiquidity, amountDeposit - amountBorrow);
    }

    function testBorrowRevertsIfCollateralBreaks() public {
        _depositAs(USER, 10 ether);

        vm.prank(USER);
        vm.expectRevert(Lending.Lending__BorrowExceedsCollateral.selector);
        lending.borrow(10 ether, ETH_SENTINEL);
    }

    function testBorrowRevertsIfNotEnoughLiquidity() public {
        _depositAs(USER, 1 ether);

        vm.prank(USER);
        vm.expectRevert(Lending.Lending__BorrowExceedsCollateral.selector);
        lending.borrow(2 ether, ETH_SENTINEL);
    }

    function testBorrowRevertsIfAmountZero() public {
        vm.prank(USER);
        vm.expectRevert(Lending.Lending__AmountZero.selector);
        lending.borrow(0, ETH_SENTINEL);
    }
}
