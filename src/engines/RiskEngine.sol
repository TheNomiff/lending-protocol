// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RiskEngine {
    //////////////////
    //// ERRORS ////
    /////////////////

    /////////////////////
    //// CONSTANTS ////
    ////////////////////

    uint256 public constant MAX_BORROW_RATIO = 50;
    uint256 public constant LIQUIDATION_THRESHOLD = 75;
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant CLOSE_FACTOR = 50;

    /////////////////////////////
    //// EXTERNAL FUNCTION ////
    ////////////////////////////

    function healthFactor(uint256 collateralUsd, uint256 debtUsd) public pure returns (uint256) {
        if (debtUsd == 0) {
            return type(uint256).max;
        }

        uint256 collateralAdjusted = (collateralUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        return (collateralAdjusted * PRECISION) / debtUsd;
    }

    function maxBorrow(uint256 collateralUsd) public pure returns (uint256) {
        return (collateralUsd * MAX_BORROW_RATIO) / LIQUIDATION_PRECISION;
    }

    function canBorrow(uint256 collateralUsd, uint256 totalDebtUsd) public pure returns (bool) {
        return totalDebtUsd <= maxBorrow(collateralUsd);
    }

    function isLiquidatable(uint256 HF) public pure returns (bool) {
        return HF < MIN_HEALTH_FACTOR;
    }

    function calculateMaxLiquidation(uint256 debt) public pure returns (uint256) {
        return (debt * CLOSE_FACTOR) / LIQUIDATION_PRECISION;
    }

    /////////////////////////////
    //// INTERNAL FUNCTION ////
    ////////////////////////////

    ///////////////////////////
    //// GETTER FUNCTION ////
    //////////////////////////
}
