// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Lending} from "../../../src/Lending.sol";
import {LendingTestBase} from "../../utils/LendingTestBase.t.sol";

contract RepayTest is LendingTestBase {
    function testRepaySuccess() public {
        _openPosition(USER, 10 ether, 4 ether);
        _repayAs(USER, 2 ether);

        (uint256 depositedAmount, uint256 borrowedAmount,) = _userPosition(USER);
        assertEq(depositedAmount, 10 ether);
        assertEq(borrowedAmount, 2 ether);
    }

    function testRepaySuccessWhileOverpaying() public {
        _openPosition(USER, 10 ether, 4 ether);
        _repayAs(USER, 10 ether);

        (, uint256 borrowedAmount,) = _userPosition(USER);
        assertEq(borrowedAmount, 0);
    }

    function testRepayExactAmount() public {
        _openPosition(USER, 10 ether, 4 ether);
        _repayAs(USER, 4 ether);

        (, uint256 borrowedAmount,) = _userPosition(USER);
        assertEq(borrowedAmount, 0);
    }

    function testRepayRevertsIfNoDebt() public {
        _depositAs(USER, 1 ether);

        vm.prank(USER);
        vm.expectRevert(Lending.Lending__NotAnyBorrow.selector);
        lending.repay{value: 1 ether}();
    }

    function testRepayRevertsIfAmountZero() public {
        vm.prank(USER);
        vm.expectRevert(Lending.Lending__AmountZero.selector);
        lending.repay{value: 0}();
    }
}
