// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskTestBase} from "../../utils/RiskTestBase.t.sol";

contract RiskEngineBorrowTest is RiskTestBase {
    function testCanBorrowReturnsTrue() public view {
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 30 ether;

        bool canBorrow = riskEngine.canBorrow(collateralUsd, debtUsd);

        assertTrue(canBorrow);
        assertEq(riskEngine.maxBorrow(collateralUsd), 50 ether);
    }

    function testCanBorrowReturnsFalse() public view {
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 60 ether;

        bool canBorrow = riskEngine.canBorrow(collateralUsd, debtUsd);

        assertFalse(canBorrow);
        assertEq(riskEngine.maxBorrow(collateralUsd), 50 ether);
    }

    function testCanBorrowAtExactLimit() public view {
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 50 ether;

        uint256 maxBorrow = riskEngine.maxBorrow(collateralUsd);
        bool canBorrow = riskEngine.canBorrow(collateralUsd, debtUsd);

        assertTrue(canBorrow);
        assertEq(riskEngine.maxBorrow(collateralUsd), 50 ether);
        assert(debtUsd == maxBorrow);
    }
}
