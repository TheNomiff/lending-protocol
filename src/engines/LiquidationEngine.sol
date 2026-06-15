// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LiquidationEngine {
    //////////////////
    //// ERRORS ////
    /////////////////

    error LiquidationEngine__NotOwner();
    error LiquidationEngine__InvalidOwner();
    error LiquidationEngine__InvalidCloseFactor();
    error LiquidationEngine__InvalidBonus();
    error LiquidationEngine__ValueUnchanged();

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

    /////////////////////
    //// CONSTANTS ////
    ////////////////////

    uint256 public constant LIQUIDATION_PRECISION = 100;

    uint256 public closeFactor = 50;
    uint256 public liquidationBonus = 10;

    ///////////////////////
    //// CONSTRUCTOR ////
    ///////////////////////

    constructor() {
        owner = msg.sender;
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
        if (newBonus == 0 || newBonus > 100) revert LiquidationEngine__InvalidBonus();
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
