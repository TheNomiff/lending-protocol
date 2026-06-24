// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LiquidationTestBase} from "../../utils/LiquidationTestBase.t.sol";
import {LiquidationEngine} from "../../../src/engines/LiquidationEngine.sol";

contract LiquidationEngineConstructorTest is LiquidationTestBase {
    function testPreviewLiquidationNormal() public view {
        uint256 collateralAmount = 100 ether;
        uint256 debtAmount = 80 ether;
        uint256 repayAmount = 20 ether;
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 80 ether;

        LiquidationEngine.LiquidationPreview memory preview =
            liquidationEngine.previewLiquidation(collateralAmount, debtAmount, repayAmount, collateralUsd, debtUsd);
        assertEq(preview.maxLiquidation, 40 ether);
        assertEq(preview.effectiveRepay, 20 ether);
        assertEq(preview.bonus, 2 ether);
        assertEq(preview.collateralToSeize, 22 ether);
        assertEq(preview.remainingDebt, 60 ether);
        assertEq(preview.remainingCollateral, 78 ether);
        assertEq(preview.refundAmount, 0);
    }

    function testPreviewLiquidationCapsRepay() public view {
        uint256 collateralAmount = 100 ether;
        uint256 debtAmount = 80 ether;
        uint256 repayAmount = 100 ether;
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 80 ether;

        LiquidationEngine.LiquidationPreview memory preview =
            liquidationEngine.previewLiquidation(collateralAmount, debtAmount, repayAmount, collateralUsd, debtUsd);

        assertEq(preview.maxLiquidation, 40 ether);
        assertEq(preview.effectiveRepay, 40 ether);
    }

    function testPreviewLiquidationCalculatesRefund() public view {
        uint256 collateralAmount = 100 ether;
        uint256 debtAmount = 80 ether;
        uint256 repayAmount = 90 ether;
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 80 ether;

        LiquidationEngine.LiquidationPreview memory preview =
            liquidationEngine.previewLiquidation(collateralAmount, debtAmount, repayAmount, collateralUsd, debtUsd);

        assertEq(preview.refundAmount, 50 ether);
    }

    function testPreviewLiquidationReturnsZeroRemainingCollateral() public view {
        uint256 collateralAmount = 20 ether;
        uint256 debtAmount = 80 ether;
        uint256 repayAmount = 40 ether;
        uint256 collateralUsd = 20 ether;
        uint256 debtUsd = 80 ether;

        LiquidationEngine.LiquidationPreview memory preview =
            liquidationEngine.previewLiquidation(collateralAmount, debtAmount, repayAmount, collateralUsd, debtUsd);

        assertEq(preview.collateralToSeize, 44 ether);
        assertEq(preview.remainingDebt, 40 ether);
        assertEq(preview.remainingCollateral, 0);
    }

    function testPreviewCalculatesHealthFactorBefore() public view {
        uint256 collateralAmount = 100 ether;
        uint256 debtAmount = 80 ether;
        uint256 repayAmount = 20 ether;

        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 80 ether;

        LiquidationEngine.LiquidationPreview memory preview =
            liquidationEngine.previewLiquidation(collateralAmount, debtAmount, repayAmount, collateralUsd, debtUsd);

        uint256 expectedHF = riskEngine.healthFactor(collateralUsd, debtUsd);

        assertEq(preview.healthFactorBefore, expectedHF);
    }

    function testPreviewCalculatesHealthFactorAfter() public view {
        uint256 collateralAmount = 100 ether;
        uint256 debtAmount = 80 ether;
        uint256 repayAmount = 20 ether;

        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 80 ether;

        LiquidationEngine.LiquidationPreview memory preview =
            liquidationEngine.previewLiquidation(collateralAmount, debtAmount, repayAmount, collateralUsd, debtUsd);

        uint256 remainingCollateralUsd = (collateralUsd * preview.remainingCollateral) / collateralAmount;

        uint256 remainingDebtUsd = (debtUsd * preview.remainingDebt) / debtAmount;

        uint256 expectedHF = riskEngine.healthFactor(remainingCollateralUsd, remainingDebtUsd);

        assertEq(preview.healthFactorAfter, expectedHF);
    }

    function testPreviewCanExecuteReturnsFalseForHealthyPosition() public view {
        uint256 collateralAmount = 200 ether;
        uint256 debtAmount = 50 ether;
        uint256 repayAmount = 20 ether;

        uint256 collateralUsd = 200 ether;
        uint256 debtUsd = 50 ether;

        LiquidationEngine.LiquidationPreview memory preview =
            liquidationEngine.previewLiquidation(collateralAmount, debtAmount, repayAmount, collateralUsd, debtUsd);

        assertFalse(preview.canExecute);
    }

    function testPreviewUsesEffectiveSeizureWhenCollateralIsInsufficient() public view {
        uint256 collateralAmount = 20 ether;
        uint256 debtAmount = 40 ether;
        uint256 repayAmount = 20 ether;

        uint256 collateralUsd = 20 ether;
        uint256 debtUsd = 40 ether;

        LiquidationEngine.LiquidationPreview memory preview =
            liquidationEngine.previewLiquidation(collateralAmount, debtAmount, repayAmount, collateralUsd, debtUsd);

        assertEq(preview.effectiveRepay, 20 ether);
        assertEq(preview.bonus, 2 ether);
        assertEq(preview.collateralToSeize, 22 ether);
        assertEq(preview.effectiveSeizure, 20 ether);
        assertEq(preview.remainingDebt, 20 ether);
        assertEq(preview.remainingCollateral, 0);
    }

    function testPreviewReturnsMaxHealthFactorWhenDebtBecomesZero() public {
        uint256 collateralAmount = 80 ether;
        uint256 debtAmount = 40 ether;
        uint256 repayAmount = 40 ether;

        uint256 collateralUsd = 80 ether;
        uint256 debtUsd = 40 ether;

        liquidationEngine.updateCloseFactor(100);

        LiquidationEngine.LiquidationPreview memory preview =
            liquidationEngine.previewLiquidation(collateralAmount, debtAmount, repayAmount, collateralUsd, debtUsd);

        assertEq(preview.effectiveRepay, 40 ether);
        assertEq(preview.bonus, 4 ether);
        assertEq(preview.collateralToSeize, 44 ether);
        assertEq(preview.effectiveSeizure, 44 ether);
        assertEq(preview.remainingDebt, 0 ether);
        assertEq(preview.remainingCollateral, 36 ether);
        assertEq(preview.healthFactorAfter, type(uint256).max);
    }
}
