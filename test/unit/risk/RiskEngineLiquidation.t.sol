// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskTestBase} from "../../utils/RiskTestBase.t.sol";

contract RiskEngineLiquidationTest is RiskTestBase {
    function testIsLiquidatableReturnsTrue() public view {
        uint256 collateralUsd = 50 ether;
        uint256 debtUsd = 40 ether;

        uint256 HF = riskEngine.healthFactor(collateralUsd, debtUsd);

        assertTrue(riskEngine.isLiquidatable(HF));
        assertLt(HF, riskEngine.minHealthFactor());
    }

    function testIsLiquidatableReturnsFalse() public view {
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 40 ether;

        uint256 HF = riskEngine.healthFactor(collateralUsd, debtUsd);

        assertFalse(riskEngine.isLiquidatable(HF));
        assertGt(HF, riskEngine.minHealthFactor());
    }

    function testCalculateMaxLiquidation() public view {
        uint256 debtUsd = 40 ether;
        uint256 maxLiquidation = liquidationEngine.calculateMaxLiquidation(debtUsd);

        assertEq(maxLiquidation, 20 ether);
    }

    function testCalculateSeizedCollateral() public view {
        uint256 repayAmount = 10 ether;
        uint256 expectedSeized =
            repayAmount + ((repayAmount * liquidationEngine.liquidationBonus()) / riskEngine.LIQUIDATION_PRECISION());
        uint256 seizedCollateral = liquidationEngine.calculateSeizedCollateral(repayAmount);

        assertEq(seizedCollateral, expectedSeized);
    }

    function testIsLiquidatableAtExactMinimumHealthFactor() public view {
        uint256 HF = riskEngine.minHealthFactor();

        assertFalse(riskEngine.isLiquidatable(HF));
    }
}
