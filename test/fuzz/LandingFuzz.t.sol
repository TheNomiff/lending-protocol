// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Landing} from "../../src/Landing.sol";
import {LandingTestBase} from "../utils/LandingTestBase.t.sol";

contract LandingFuzzTest is LandingTestBase {
    function testFuzz_DepositIncreasesBalanceAndLiquidity(
        uint96 depositAmount
    ) public {
        uint256 amount = bound(uint256(depositAmount), 1 wei, 100 ether);

        _fundUser(USER, amount);
        _depositAs(USER, amount);

        (uint256 depositedAmount, , ) = _userPosition(USER);
        assertEq(depositedAmount, amount);
        assertEq(landing.totalLiquidity(), amount);
    }

    function testFuzz_BorrowWithinLimitSucceeds(
        uint96 depositAmount,
        uint96 borrowAmount
    ) public {
        uint256 deposit = bound(uint256(depositAmount), 2 ether, 100 ether);
        uint256 borrow = bound(uint256(borrowAmount), 1 wei, deposit / 2);

        _fundUser(USER, deposit);
        _depositAs(USER, deposit);
        _borrowAs(USER, borrow);

        (, uint256 borrowedAmount, ) = _userPosition(USER);
        assertEq(borrowedAmount, borrow);
        assertEq(landing.totalLiquidity(), deposit - borrow);
    }

    function testFuzz_RepayNeverLeavesNegativeDebt(
        uint96 depositAmount,
        uint96 borrowAmount,
        uint96 repayAmount
    ) public {
        uint256 deposit = bound(uint256(depositAmount), 2 ether, 100 ether);
        uint256 borrow = bound(uint256(borrowAmount), 1 wei, deposit / 2);
        uint256 repay = bound(uint256(repayAmount), 1 wei, 150 ether);

        _fundUser(USER, deposit + repay);
        _depositAs(USER, deposit);
        _borrowAs(USER, borrow);
        _repayAs(USER, repay);

        (, uint256 borrowedAmount, ) = _userPosition(USER);
        assertLe(borrowedAmount, borrow);
    }
}
