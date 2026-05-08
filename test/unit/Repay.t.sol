// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Landing} from "../../src/Landing.sol";
import {LandingTestBase} from "../utils/LandingTestBase.t.sol";

contract RepayTest is LandingTestBase {
    function testRepaySuccess() public {
        _openPosition(USER, 10 ether, 4 ether);
        _repayAs(USER, 2 ether);

        (uint256 depositedAmount, uint256 borrowedAmount, ) = _userPosition(USER);
        assertEq(depositedAmount, 10 ether);
        assertEq(borrowedAmount, 2 ether);
    }

    function testRepaySuccessWhileOverpaying() public {
        _openPosition(USER, 10 ether, 4 ether);
        _repayAs(USER, 10 ether);

        (, uint256 borrowedAmount, ) = _userPosition(USER);
        assertEq(borrowedAmount, 0);
    }

    function testRepayExactAmount() public {
        _openPosition(USER, 10 ether, 4 ether);
        _repayAs(USER, 4 ether);

        (, uint256 borrowedAmount, ) = _userPosition(USER);
        assertEq(borrowedAmount, 0);
    }

    function testRepayRevertsIfNoDebt() public {
        _depositAs(USER, 1 ether);

        vm.prank(USER);
        vm.expectRevert(Landing.Landing__NotAnyBorrow.selector);
        landing.repay{value: 1 ether}();
    }

    function testRepayRevertsIfAmountZero() public {
        vm.prank(USER);
        vm.expectRevert(Landing.Landing__AmountZero.selector);
        landing.repay{value: 0}();
    }
}
