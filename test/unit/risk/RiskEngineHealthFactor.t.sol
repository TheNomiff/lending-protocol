// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskTestBase} from "../../utils/RiskTestBase.t.sol";

contract RiskEngineHealthFactorTest is RiskTestBase {
    function testHealthFactorReturnsMaxWhenDebtZero() public view {
        uint256 HF = riskEngine.healthFactor(100 ether, 0);
        assertEq(HF, type(uint256).max);
    }

    function testHealthFactorCalculationDynamic() public view {
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 30 ether;

        uint256 expectedCollateral =
            (collateralUsd * riskEngine.liquidationThreshold()) / riskEngine.LIQUIDATION_PRECISION();
        uint256 expectedHF = (expectedCollateral * riskEngine.PRECISION()) / debtUsd;

        uint256 HF = riskEngine.healthFactor(collateralUsd, debtUsd);
        assertEq(HF, expectedHF);
    }

    /*
        HF claculation formula:

        collateralAdjusted = (collateral * liquidationThreshold) / LIQUIDATION_PRECISION,

        return (collateralAdjusted * PRECISION) / debt
    */

    function testHealthFactorBelowOne() public view {
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 80 ether;

        uint256 HF = riskEngine.healthFactor(collateralUsd, debtUsd);

        assertTrue(HF < 1e18);
        assertEq(HF, 0.9375 ether);
    }

    function testHealthFactorAboveOne() public view {
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 30 ether;

        uint256 HF = riskEngine.healthFactor(collateralUsd, debtUsd);

        assertGt(HF, riskEngine.minHealthFactor());
        assertEq(HF, 2.5e18);
    }
}
