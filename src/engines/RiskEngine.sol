// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RiskEngine {
    //////////////////
    //// ERRORS ////
    /////////////////

    error RiskEngine__NotOwner();
    error RiskEngine__InvalidOwner();
    error RiskEngine__InvalidGuardian();
    error RiskEngine__InvalidRatio();
    error RiskEngine__InvalidThreshold();
    error RiskEngine__InvalidCloseFactor();
    error RiskEngine__InvalidHealthFactor();
    error RiskEngine__InvalidBonus();
    error RiskEngine__InvalidRiskParameters();
    error RiskEngine__BorrowPaused();
    error RiskEngine__LiquidationPaused();
    error RiskEngine__DepositPaused();
    error RiskEngine__InvalidCaps();

    //////////////////
    //// EVENTS ////
    /////////////////

    event MaxBorrowUpdated(uint256 oldValue, uint256 newValue);
    event ThresholdUpdated(uint256 oldValue, uint256 newValue);
    event CloseFactorUpdated(uint256 oldValue, uint256 newValue);
    event HealthFactorUpdated(uint256 oldValue, uint256 newValue);
    event LiquidationBonusUpdated(uint256 oldValue, uint256 newValue);
    event BorrowPaused();
    event LiquidationPaused();
    event DepositPaused();
    event BorrowUnpaused();
    event LiquidationUnpaused();
    event DepositUnpaused();
    event SupplyCapUpdated(uint256 oldCap, uint256 newCap);
    event BorrowCapUpdated(uint256 oldCap, uint256 newCap);

    /////////////////////
    //// MODIFIERS ////
    /////////////////////

    modifier onlyOwner() {
        if (msg.sender != owner) revert RiskEngine__NotOwner();
        _;
    }

    modifier onlyGuardian() {
        if (msg.sender != guardian) revert RiskEngine__InvalidGuardian();
        _;
    }

    ////////////////////////////
    //// OWNER & GUARDIAN ////
    ///////////////////////////

    address public owner;
    address public guardian;

    /////////////////////
    //// CONSTANTS ////
    ////////////////////

    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant PRECISION = 1e18;

    //////////////////////////
    //// STATE VARIABLE ////
    /////////////////////////

    uint256 public maxBorrowRatio = 50;
    uint256 public closeFactor = 50;
    uint256 public liquidationBonus = 10;
    uint256 public minHealthFactor = 1e18;
    uint256 public liquidationThreshold = 75;
    uint256 public supplyCap;
    uint256 public borrowCap;

    ///////////////////////////
    //// EMERGENCY PAUSE ////
    ///////////////////////////

    bool public borrowPaused;
    bool public liquidationPaused;
    bool public depositPaused;

    ///////////////////////
    //// CONSTRUCTOR ////
    ///////////////////////

    constructor(uint256 _supplyCap, uint256 _borrowCap) {
        owner = msg.sender;
        guardian = msg.sender;

        if (_supplyCap == 0) revert RiskEngine__InvalidCaps();

        if (_borrowCap == 0) revert RiskEngine__InvalidCaps();

        if (_borrowCap > _supplyCap) revert RiskEngine__InvalidCaps();

        supplyCap = _supplyCap;
        borrowCap = _borrowCap;
    }

    // V1 assumes debt asset and collateral asset are same asset (ETH)
    // Multi-asset version must convert through oracle prices

    /////////////////////////////
    //// EXTERNAL FUNCTION ////
    ////////////////////////////

    function healthFactor(uint256 collateralUsd, uint256 debtUsd) external view returns (uint256) {
        if (debtUsd == 0) {
            return type(uint256).max;
        }

        uint256 collateralAdjusted = (collateralUsd * liquidationThreshold) / LIQUIDATION_PRECISION;

        return (collateralAdjusted * PRECISION) / debtUsd;
    }

    function canBorrow(uint256 collateralUsd, uint256 totalDebtUsd) external view returns (bool) {
        return _isDebtSafe(collateralUsd, totalDebtUsd);
    }

    function maxBorrow(uint256 collateralUsd) external view returns (uint256) {
        return _maxBorrow(collateralUsd);
    }

    function isLiquidatable(uint256 HF) external view returns (bool) {
        return HF < minHealthFactor;
    }

    function calculateMaxLiquidation(uint256 debt) external view returns (uint256) {
        return (debt * closeFactor) / LIQUIDATION_PRECISION;
    }

    function calculateSeizedCollateral(uint256 repayAmount) external view returns (uint256) {
        return repayAmount + ((repayAmount * liquidationBonus) / LIQUIDATION_PRECISION);
    }

    function canWithdraw(uint256 remainingCollateralUsd, uint256 debtUsd) external view returns (bool) {
        return _isDebtSafe(remainingCollateralUsd, debtUsd);
    }

    function canSupply(uint256 currentSupply, uint256 amount) external view returns (bool) {
        return currentSupply + amount <= supplyCap;
    }

    function canGlobalBorrow(uint256 currentBorrow, uint256 amount) external view returns (bool) {
        return currentBorrow + amount <= borrowCap;
    }

    /////////////////////////////
    //// INTERNAL FUNCTION ////
    ////////////////////////////

    function _isDebtSafe(uint256 collateralUsd, uint256 debtUsd) internal view returns (bool) {
        return debtUsd <= _maxBorrow(collateralUsd);
    }

    function _maxBorrow(uint256 collateralUsd) internal view returns (uint256) {
        return (collateralUsd * maxBorrowRatio) / LIQUIDATION_PRECISION;
    }

    /////////////////////////////////////
    //// EMERGENCY PAUSE FUNCTIONS ////
    /////////////////////////////////////

    function pauseBorrowing() external onlyGuardian {
        borrowPaused = true;

        emit BorrowPaused();
    }

    function unpauseBorrowing() external onlyGuardian {
        borrowPaused = false;

        emit BorrowUnpaused();
    }

    function pauseLiquidation() external onlyGuardian {
        liquidationPaused = true;

        emit LiquidationPaused();
    }

    function unpauseLiquidation() external onlyGuardian {
        liquidationPaused = false;

        emit LiquidationUnpaused();
    }

    function pauseDepositing() external onlyGuardian {
        depositPaused = true;

        emit DepositPaused();
    }

    function unpauseDepositing() external onlyGuardian {
        depositPaused = false;

        emit DepositUnpaused();
    }

    ///////////////////////////
    //// OWNER FUNCTIONS ////
    //////////////////////////

    function updateMaxBorrowRatio(uint256 newRatio) external onlyOwner {
        if (newRatio == 0 || newRatio > 100) revert RiskEngine__InvalidRatio();
        if (newRatio >= liquidationThreshold) {
            revert RiskEngine__InvalidRiskParameters();
        }

        uint256 oldRatio = maxBorrowRatio;
        maxBorrowRatio = newRatio;

        emit MaxBorrowUpdated(oldRatio, newRatio);
    }

    function updateLiquidationThreshold(uint256 newThreshold) external onlyOwner {
        if (newThreshold == 0 || newThreshold > 100) {
            revert RiskEngine__InvalidThreshold();
        }
        if (newThreshold <= maxBorrowRatio) {
            revert RiskEngine__InvalidRiskParameters();
        }

        uint256 oldThreshold = liquidationThreshold;
        liquidationThreshold = newThreshold;

        emit ThresholdUpdated(oldThreshold, newThreshold);
    }

    function updateCloseFactor(uint256 newFactor) external onlyOwner {
        if (newFactor == 0 || newFactor > 100) {
            revert RiskEngine__InvalidCloseFactor();
        }

        uint256 oldFactor = closeFactor;
        closeFactor = newFactor;

        emit CloseFactorUpdated(oldFactor, newFactor);
    }

    function updateMinimumHealthFactor(uint256 newHF) external onlyOwner {
        if (newHF == 0 || newHF < 1e18) {
            revert RiskEngine__InvalidHealthFactor();
        }

        uint256 oldHF = minHealthFactor;
        minHealthFactor = newHF;

        emit HealthFactorUpdated(oldHF, newHF);
    }

    function updateLiquidationBonus(uint256 newBonus) external onlyOwner {
        if (newBonus == 0 || newBonus > 100) revert RiskEngine__InvalidBonus();
        uint256 oldBonus = liquidationBonus;
        liquidationBonus = newBonus;

        emit LiquidationBonusUpdated(oldBonus, newBonus);
    }

    function updateSupplyCap(uint256 newCap) external onlyOwner {
        if (newCap > supplyCap) revert RiskEngine__InvalidCaps();

        uint256 oldCap = supplyCap;
        supplyCap = newCap;

        emit SupplyCapUpdated(oldCap, newCap);
    }

    function updateBorrowCap(uint256 newCap) external onlyOwner {
        if (newCap > borrowCap) revert RiskEngine__InvalidCaps();

        uint256 oldCap = borrowCap;
        borrowCap = newCap;

        emit BorrowCapUpdated(oldCap, newCap);
    }

    /////////////////////
    //// OWNERSHIP ////
    ////////////////////

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert RiskEngine__InvalidOwner();
        }

        owner = newOwner;
    }

    function transferGuardian(address newGuardian) external onlyOwner {
        if (newGuardian == address(0)) revert RiskEngine__InvalidGuardian();

        guardian = newGuardian;
    }
}
