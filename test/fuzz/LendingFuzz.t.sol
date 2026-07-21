// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Lending} from "../../src/Lending.sol";
import {LendingTestBase} from "../utils/LendingTestBase.t.sol";

contract LendingFuzzTest is LendingTestBase {
    function testFuzz_DepositIncreasesBalanceAndLiquidity(uint96 depositAmount) public {
        uint256 amount = bound(uint256(depositAmount), 1 wei, 100 ether);

        _fundUser(USER, amount);
        _depositAs(USER, amount);

        (uint256 depositedAmount,,) = _userPosition(USER, ETH_SENTINEL);

        (,, uint256 totalLiquidity,,) = lending.reserves(ETH_SENTINEL);

        assertEq(totalLiquidity, amount);

        assertEq(depositedAmount, amount);
        assertEq(totalLiquidity, amount);
    }

    function testFuzz_BorrowWithinLimitSucceeds(uint96 depositAmount, uint96 borrowAmount) public {
        uint256 deposit = bound(uint256(depositAmount), 2 ether, 100 ether);
        uint256 borrow = bound(uint256(borrowAmount), 1 wei, deposit / 2);

        _fundUser(USER, deposit);
        _depositAs(USER, deposit);
        _borrowAs(USER, borrow);

        (, uint256 borrowedAmount,) = _userPosition(USER, ETH_SENTINEL);

        (,, uint256 totalLiquidity,,) = lending.reserves(ETH_SENTINEL);

        assertEq(borrowedAmount, borrow);
        assertEq(totalLiquidity, deposit - borrow);
    }

    function testFuzz_RepayNeverLeavesNegativeDebt(uint96 depositAmount, uint96 borrowAmount, uint96 repayAmount)
        public
    {
        uint256 deposit = bound(uint256(depositAmount), 2 ether, 100 ether);
        uint256 borrow = bound(uint256(borrowAmount), 1 wei, deposit / 2);
        uint256 repay = bound(uint256(repayAmount), 1 wei, 150 ether);

        _fundUser(USER, deposit + repay);
        _depositAs(USER, deposit);
        _borrowAs(USER, borrow);
        _repayAs(USER, repay);

        (, uint256 borrowedAmount,) = _userPosition(USER, ETH_SENTINEL);
        assertLe(borrowedAmount, borrow);
    }
}
