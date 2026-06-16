// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LiquidationTestBase} from "../../utils/LiquidationTestBase.t.sol";

contract LiquidationEngineCalculationTest is LiquidationTestBase {
    function testCalculateMaxLiquidation() public view {
        uint256 debtUsd = 40 ether;
        uint256 maxLiquidation = liquidationEngine.calculateMaxLiquidation(debtUsd);

        assertEq(maxLiquidation, 20 ether);
    }

    function testCalculateSeizedCollateral() public view {
        uint256 repayAmount = 10 ether;
        uint256 expectedSeized = repayAmount
            + ((repayAmount * liquidationEngine.liquidationBonus()) / liquidationEngine.LIQUIDATION_PRECISION());
        uint256 seizedCollateral = liquidationEngine.calculateSeizedCollateral(repayAmount);

        assertEq(seizedCollateral, expectedSeized);
    }

    function testCalculateLiquidationBonus() public view {
        uint256 repayAmount = 10 ether;

        uint256 bonus = liquidationEngine.calculateLiquidationBonus(repayAmount);

        assertEq(bonus, 1 ether); // 10% of 10 ether
    }

    function testCalculateLiquidationBonusReturnsZeroForZeroRepay() public view {
        assertEq(liquidationEngine.calculateLiquidationBonus(0), 0);
    }
}
