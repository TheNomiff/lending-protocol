// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskEngine} from "./RiskEngine.sol";

contract LiquidationEngine {
    ////////////////////
    ///// STRUCT /////
    ///////////////////

    struct LiquidationPreview {
        uint256 maxLiquidation;
        uint256 effectiveRepay;
        uint256 bonus;
        uint256 collateralToSeize;
        uint256 effectiveSeizure;
        uint256 remainingDebt;
        uint256 remainingCollateral;
        uint256 healthFactorBefore;
        uint256 healthFactorAfter;
        uint256 refundAmount;
        bool canExecute;
    }

    //////////////////
    //// ERRORS ////
    /////////////////

    error LiquidationEngine__NotOwner();
    error LiquidationEngine__InvalidOwner();
    error LiquidationEngine__InvalidCloseFactor();
    error LiquidationEngine__InvalidBonus();
    error LiquidationEngine__ValueUnchanged();
    error LiquidationEngine__InvalidRiskEngine();

    //////////////////
    //// EVENTS ////
    /////////////////

    event CloseFactorUpdated(uint256 oldValue, uint256 newValue);
    event LiquidationBonusUpdated(uint256 oldValue, uint256 newValue);

    /////////////////////
    //// MODIFIERS ////
    /////////////////////

    modifier onlyOwner() {
        if (msg.sender != owner) revert LiquidationEngine__NotOwner();
        _;
    }

    /////////////////
    //// OWNER ////
    /////////////////

    address public owner;
    RiskEngine public riskEngine;

    /////////////////////
    //// CONSTANTS ////
    ////////////////////

    uint256 public constant LIQUIDATION_PRECISION = 100;

    uint256 public closeFactor = 50;
    uint256 public liquidationBonus = 10;

    ///////////////////////
    //// CONSTRUCTOR ////
    ///////////////////////

    constructor(address _riskEngine) {
        owner = msg.sender;

        if (_riskEngine == address(0)) {
            revert LiquidationEngine__InvalidRiskEngine();
        }

        riskEngine = RiskEngine(_riskEngine);
    }

    /////////////////////////////
    //// EXTERNAL FUNCTION ////
    ////////////////////////////

    function calculateMaxLiquidation(uint256 debtUsd) external view returns (uint256) {
        return (debtUsd * closeFactor) / LIQUIDATION_PRECISION;
    }

    function calculateLiquidationBonus(uint256 repayAmount) external view returns (uint256) {
        return (repayAmount * liquidationBonus) / LIQUIDATION_PRECISION;
    }

    function calculateSeizedCollateral(uint256 repayAmount) external view returns (uint256) {
        return repayAmount + ((repayAmount * liquidationBonus) / LIQUIDATION_PRECISION);
    }

    function canLiquidate(uint256 healthFactor) external view returns (bool) {
        return riskEngine.isLiquidatable(healthFactor);
    }

    function remainingDebtAfterLiquidation(uint256 currentDebt, uint256 repaidDebt) external pure returns (uint256) {
        if (repaidDebt >= currentDebt) {
            return 0;
        }

        return currentDebt - repaidDebt;
    }

    function remainingCollateralAfterSeizure(uint256 collateralBefore, uint256 collateralSeized)
        external
        pure
        returns (uint256)
    {
        if (collateralSeized >= collateralBefore) {
            return 0;
        }

        return collateralBefore - collateralSeized;
    }

    function previewLiquidation(
        uint256 collateralAmount,
        uint256 debtAmount,
        uint256 repayAmount,
        uint256 collateralUsd,
        uint256 debtUsd
    ) external view returns (LiquidationPreview memory preview) {
        preview.maxLiquidation = (debtAmount * closeFactor) / LIQUIDATION_PRECISION;

        preview.effectiveRepay = repayAmount > preview.maxLiquidation ? preview.maxLiquidation : repayAmount;

        preview.refundAmount = repayAmount - preview.effectiveRepay;

        preview.bonus = (preview.effectiveRepay * liquidationBonus) / LIQUIDATION_PRECISION;

        preview.collateralToSeize = preview.effectiveRepay + preview.bonus;

        preview.effectiveSeizure =
            preview.collateralToSeize > collateralAmount ? collateralAmount : preview.collateralToSeize;

        preview.remainingDebt = preview.effectiveRepay >= debtAmount ? 0 : debtAmount - preview.effectiveRepay;

        preview.remainingCollateral =
            preview.effectiveSeizure >= collateralAmount ? 0 : collateralAmount - preview.effectiveSeizure;

        preview.healthFactorBefore = riskEngine.healthFactor(collateralUsd, debtUsd);

        uint256 remainingCollateralUsd = (collateralUsd * preview.remainingCollateral) / collateralAmount;

        uint256 remainingDebtUsd = (debtUsd * preview.remainingDebt) / debtAmount;

        preview.healthFactorAfter = riskEngine.healthFactor(remainingCollateralUsd, remainingDebtUsd);

        preview.canExecute = preview.effectiveRepay > 0 && preview.healthFactorBefore < riskEngine.minHealthFactor()
            && preview.healthFactorAfter > preview.healthFactorBefore;

        return preview;
    }

    /////////////////////////////
    //// INTERNAL FUNCTION ////
    ////////////////////////////

    ///////////////////////////
    //// OWNER FUNCTIONS ////
    //////////////////////////

    function updateCloseFactor(uint256 newFactor) external onlyOwner {
        if (newFactor == 0 || newFactor > 100) {
            revert LiquidationEngine__InvalidCloseFactor();
        }
        if (newFactor == closeFactor) {
            revert LiquidationEngine__ValueUnchanged();
        }

        uint256 oldFactor = closeFactor;
        closeFactor = newFactor;

        emit CloseFactorUpdated(oldFactor, newFactor);
    }

    function updateLiquidationBonus(uint256 newBonus) external onlyOwner {
        if (newBonus == 0 || newBonus > 100) {
            revert LiquidationEngine__InvalidBonus();
        }
        if (newBonus == liquidationBonus) {
            revert LiquidationEngine__ValueUnchanged();
        }

        uint256 oldBonus = liquidationBonus;
        liquidationBonus = newBonus;

        emit LiquidationBonusUpdated(oldBonus, newBonus);
    }

    /////////////////////
    //// OWNERSHIP ////
    ////////////////////

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert LiquidationEngine__InvalidOwner();
        }

        owner = newOwner;
    }
}
