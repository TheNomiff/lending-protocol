// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PriceOracle} from "./oracle/PriceOracle.sol";
import {RiskEngine} from "./engines/RiskEngine.sol";
import {LiquidationEngine} from "./engines/LiquidationEngine.sol";
import {AssetRegistry} from "./registry/AssetRegistry.sol";

contract Lending is ReentrancyGuard {
    ////////////////////
    ///// STRUCT /////
    ///////////////////

    struct UserAssetPosition {
        uint256 deposited;
        uint256 borrowed;
        uint256 lastBorrowTimestamp;
    }

    struct ReserveData {
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 totalLiquidity;
        uint256 borrowIndex;
        uint256 liquidityIndex;
    }

    ////////////////////
    ///// ERRORS /////
    ///////////////////

    error Lending__AmountZero();
    error Lending__BorrowedFailed();
    error Lending__BorrowExceedsCollateral();
    error Lending__NotEnoughLiquidity();
    error Lending__InsufficientBalance();
    error Lending__NotAnyBorrow();
    error Lending__WithdrawnFailed();
    error Lending__RefundFailed();
    error Lending__InvalidOracle();
    error Lending__InvalidRiskEngine();
    error Lending__BreakHealthFactor();
    error Lending__HealthFactorOk();
    error Lending__LiquidationBonusFailed();
    error Lending__HealthFactorNotImproved();
    error Lending__SupplyCapExceeded();
    error Lending__BorrowCapExceeded();
    error Lending__BorrowPaused();
    error Lending__DepositPaused();
    error Lending__LiquidationPaused();
    error Lending__InvalidAssetRegistry();
    error Lending__AssetNotRegistered();
    error Lending__AssetDisabled();
    error Lending__ReserveNotInitialized();

    ////////////////////
    ///// EVENTS /////
    ///////////////////

    event Deposited(address indexed user, address indexed token, uint256 amount);

    event Withdrawn(address indexed user, address indexed token, uint256 amount);

    event Borrowed(address indexed user, address indexed token, uint256 amount);

    event Repaid(address indexed user, address indexed token, uint256 amount);

    event Liquidated(address indexed liquidator, address indexed user, uint256 debtRepaid, uint256 collateralSeized);

    event ReserveInitialized(address indexed asset, uint256 borrowIndex, uint256 liquidityIndex);

    event UserPositionUpdated(address indexed user, address indexed asset, uint256 deposited, uint256 borrowed);

    event CollateralAssetAdded(address indexed user, address indexed asset);

    event CollateralAssetRemoved(address indexed user, address indexed asset);

    event DebtAssetAdded(address indexed user, address indexed asset);

    event DebtAssetRemoved(address indexed user, address indexed asset);

    event StorageMigrated(address indexed user, address indexed asset, uint256 deposited, uint256 borrowed);

    ////////////////////////////////////////
    ///// STATE VARIABLE & CONSTANTS /////
    //////////////////////////////////////

    uint256 public constant INTEREST_RATE = 5e16;
    uint256 public constant INTEREST_RATE_PER_SECOND = INTEREST_RATE / 365 days;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_PRECISION = 100;
    address internal constant ETH_SENTINEL = address(0);

    ////////////////////////////////
    ///// ORACLE & IMMUTABLE /////
    ///////////////////////////////

    address public immutable owner;
    PriceOracle public oracle;
    RiskEngine public riskEngine;
    LiquidationEngine public liquidationEngine;
    AssetRegistry public assetRegistry;

    //////////////////////
    ///// MAPPINGS /////
    /////////////////////

    mapping(address => mapping(address => UserAssetPosition)) public userPositions;
    mapping(address => ReserveData) public reserves;

    mapping(address => address[]) internal _userCollateralAssets;
    mapping(address => address[]) internal _userDebtAssets;

    mapping(address => mapping(address => bool)) internal _isInCollateralList;
    mapping(address => mapping(address => bool)) internal _isInDebtList;

    ///////////////////////
    ///// MODIFIERS /////
    //////////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) revert Lending__AmountZero();
        _;
    }

    modifier reserveInitialized(address asset) {
        if (reserves[asset].borrowIndex == 0) {
            revert Lending__ReserveNotInitialized();
        }
        _;
    }

    modifier validateAsset(address asset) {
        _validateAsset(asset);
        _;
    }

    /////////////////////////
    ///// CONSTRUCTOR /////
    ////////////////////////

    constructor(address _oracle, address riskEngineAddress, address _assetRegistry) {
        if (_oracle == address(0)) revert Lending__InvalidOracle();
        oracle = PriceOracle(_oracle);

        if (riskEngineAddress == address(0)) {
            revert Lending__InvalidRiskEngine();
        }

        riskEngine = RiskEngine(riskEngineAddress);

        if (_assetRegistry == address(0)) {
            revert Lending__InvalidAssetRegistry();
        }

        assetRegistry = AssetRegistry(_assetRegistry);

        owner = msg.sender;
    }

    ////////////////////////////////
    ///// EXTERNAL FUNCTIONS /////
    ///////////////////////////////

    function deposit(address asset) external payable nonReentrant validateAsset(asset) {
        UserAssetPosition storage user = userPositions[msg.sender][asset];
        ReserveData storage reserve = reserves[asset];

        if (riskEngine.depositPaused()) {
            revert Lending__DepositPaused();
        }

        if (msg.value == 0) revert Lending__AmountZero(); // Revert if the user tries to deposit 0 ETH.

        _initReserveIfNeeded(asset);

        if (!riskEngine.canSupply(reserve.totalSupply, msg.value)) {
            revert Lending__SupplyCapExceeded();
        }

        user.deposited += msg.value; // Accounting for the user's deposited amount, which will be used as collateral for borrowing.

        _addCollateralAsset(msg.sender, asset);

        reserve.totalLiquidity += msg.value; // Total liquidity increases by the deposited amount, because the protocol can lend that amount to other users.
        reserve.totalSupply += msg.value;

        emit Deposited(msg.sender, asset, msg.value);
        emit UserPositionUpdated(msg.sender, asset, user.deposited, user.borrowed);
    }

    function borrow(uint256 amount, address asset) external nonReentrant moreThanZero(amount) validateAsset(asset) {
        if (riskEngine.borrowPaused()) {
            revert Lending__BorrowPaused();
        }

        UserAssetPosition storage user = userPositions[msg.sender][asset];
        ReserveData storage reserve = reserves[asset];

        _accrueInterest(user, reserve);

        uint256 collateralUsd = oracle.getETHValueInUSD(user.deposited); // $1000
        uint256 borrowUsd = oracle.getETHValueInUSD(amount); // $200
        uint256 currentDebt = oracle.getETHValueInUSD(getTotalDebt(msg.sender, asset)); // $0 default, but if the user already has a borrow, it will include the interest as well. for example, if the user has a borrow of $100 and the interest is $10, the currentDebt will be $110.
        uint256 totalDebt = currentDebt + borrowUsd; // $0 + $200 = $200, but if the user already has a borrow, it will be $110 + $200 = $300, and if the user has a borrow of $400, it will be $400 + $200 = $600, which exceeds the max borrow of $500 and reverts.

        if (!riskEngine.canBorrow(collateralUsd, totalDebt)) {
            revert Lending__BorrowExceedsCollateral();
        }

        if (!riskEngine.canGlobalBorrow(reserve.totalBorrow, amount)) {
            revert Lending__BorrowCapExceeded();
        }

        if (amount > reserve.totalLiquidity) {
            revert Lending__NotEnoughLiquidity(); // $200 > totalLiquidity reverts, because the protocol doesn't have enough funds to Lend.
        }

        user.borrowed += amount; // $200

        _addDebtAsset(msg.sender, asset);

        user.lastBorrowTimestamp = block.timestamp;
        reserve.totalLiquidity -= amount; // Total liqidity decreases by the borrow amount, because the protocol is Lending that amount to the user.
        reserve.totalBorrow += amount;

        // send the borrow amount to the user

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert Lending__BorrowedFailed();

        emit Borrowed(msg.sender, asset, amount);
        emit UserPositionUpdated(msg.sender, asset, user.deposited, user.borrowed);
    }

    function withdraw(uint256 amount, address asset) external nonReentrant moreThanZero(amount) validateAsset(asset) {
        UserAssetPosition storage user = userPositions[msg.sender][asset];
        ReserveData storage reserve = reserves[asset];

        uint256 currentBalance = user.deposited; // Current balance of the user.

        if (currentBalance < amount) revert Lending__InsufficientBalance(); // Revert if the user tries to withdraw more than their deposited amount.

        _accrueInterest(user, reserve); // Accrue interest on the user's borrow before allowing them to withdraw, to ensure that the health factor is calculated correctly.

        uint256 remainingCollateral = currentBalance - amount; // find the amount of collateral that the user will have after the withdrawal, to check if the health factor is still above the minimum threshold.

        uint256 remainingCollateralUsd = oracle.getETHValueInUSD(remainingCollateral); // Get the USD value of the remaining collateral.

        uint256 debtUsd = oracle.getETHValueInUSD(getTotalDebt(msg.sender, asset)); // Get the USD value of the user's debt, including the interest.

        if (!riskEngine.canWithdraw(remainingCollateralUsd, debtUsd)) {
            revert Lending__BorrowExceedsCollateral();
        }

        user.deposited = remainingCollateral;

        _removeCollateralAssetIfZero(msg.sender, asset);

        reserve.totalLiquidity -= amount;
        reserve.totalSupply -= amount;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert Lending__WithdrawnFailed();

        emit Withdrawn(msg.sender, asset, amount);
        emit UserPositionUpdated(msg.sender, asset, user.deposited, user.borrowed);
    }

    function repay(address asset) external payable nonReentrant {
        UserAssetPosition storage user = userPositions[msg.sender][asset];
        ReserveData storage reserve = reserves[asset];

        if (msg.value == 0) revert Lending__AmountZero();

        _accrueInterest(user, reserve);

        uint256 debt = user.borrowed;

        if (debt == 0) revert Lending__NotAnyBorrow();

        uint256 repayAmount = msg.value;

        if (repayAmount > debt) {
            repayAmount = debt;
        }

        uint256 extra = msg.value - repayAmount;

        user.borrowed = debt - repayAmount;

        _removeDebtAssetIfZero(msg.sender, asset);

        if (user.borrowed == 0) {
            user.lastBorrowTimestamp = 0;
        }

        reserve.totalLiquidity += repayAmount;

        if (extra > 0) {
            (bool success,) = payable(msg.sender).call{value: extra}("");

            if (!success) revert Lending__RefundFailed();
        }

        emit Repaid(msg.sender, asset, repayAmount);
    }

    function liquidate(address userAddress, address debtAsset)
        external
        payable
        nonReentrant
        moreThanZero(msg.value)
        validateAsset(debtAsset)
    {
        if (riskEngine.liquidationPaused()) {
            revert Lending__LiquidationPaused();
        }

        UserAssetPosition storage user = userPositions[userAddress][debtAsset];
        ReserveData storage reserve = reserves[debtAsset];

        _accrueInterest(user, reserve); // Accrue interest on the user's borrow before allowing them to be liquidated.
        _revertIfHealthy(user); // Revert if the user's health factor is above the minimum threshold, which mean they are not eligible for liquidation.

        uint256 currentDebt = getTotalDebt(userAddress, debtAsset); // Total debt of the user, including the interest, that need to be repaid by the liquidator to reduce the user's debt and improve their health factor.
        uint256 maxLiquidation = _calculateMaxLiquidation(currentDebt); // Calculate the maximum amount that can be liquidated based on the user's total debt, which is 50% of the user's total debt.
        uint256 repayAmount = msg.value;

        if (repayAmount > maxLiquidation) {
            repayAmount = maxLiquidation;
        } // If the liquidator tries to repay more than the maximum liquidation amount, we set the repay amount to the maximum liquidation amount to avoid overpaying and to ensure that the user's debt is reduced by the maximum allowed amount without leaving any excess amount that would need to be refunded.

        uint256 extra = msg.value - repayAmount; // Calculate any excess amount that the liquidator sent, which can happen if the liquidator tries to repay more than the maximum liquidation amount.

        if (extra > 0) {
            (bool success,) = payable(msg.sender).call{value: extra}("");

            if (!success) revert Lending__RefundFailed();
        }

        uint256 startingHF = _healthFactor(user);

        user.borrowed -= repayAmount;

        _removeDebtAssetIfZero(userAddress, debtAsset);

        reserve.totalLiquidity += repayAmount;
        reserve.totalBorrow -= repayAmount;

        if (user.borrowed > 0) {
            user.lastBorrowTimestamp = block.timestamp; // Update the user's last borrow timestamp to the current block timestamp after the liquidation, to ensure that the interest is calculated correctly for the remaining debt.
        } else {
            user.lastBorrowTimestamp = 0;
        }

        uint256 collateralToSeize = liquidationEngine.calculateSeizedCollateral(repayAmount); // Calculate the amount of collateral to seize from the user based on the repay amount and the liquidation bonus, which is 10% of the repay amount.

        if (collateralToSeize > user.deposited) {
            collateralToSeize = user.deposited;
        }

        user.deposited -= collateralToSeize; // Reduce the user's deposited collateral by the amount to seize, which is the collateral that the liquidator will receive as a reward for performing the liquidation.

        _removeCollateralAssetIfZero(userAddress, debtAsset);

        uint256 endingHF = _healthFactor(user);

        if (endingHF <= startingHF) revert Lending__HealthFactorNotImproved();

        (bool sent,) = payable(msg.sender).call{value: collateralToSeize}("");
        if (!sent) revert Lending__LiquidationBonusFailed();

        emit Liquidated(userAddress, userAddress, repayAmount, collateralToSeize);
    }

    ////////////////////////////////
    ///// INTERNAL FUNCTIONS /////
    ///////////////////////////////

    function _calculateInterest(UserAssetPosition storage user) internal view returns (uint256) {
        if (user.borrowed == 0 || user.lastBorrowTimestamp == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - user.lastBorrowTimestamp;

        return (user.borrowed * INTEREST_RATE_PER_SECOND * timeElapsed) / PRECISION;
    }

    function _accrueInterest(UserAssetPosition storage user, ReserveData storage reserve) internal {
        uint256 interest = _calculateInterest(user);

        if (interest > 0) {
            user.borrowed += interest;
            reserve.totalBorrow += interest;
        }

        if (user.borrowed > 0) {
            user.lastBorrowTimestamp = block.timestamp;
        }
    }

    function _healthFactor(UserAssetPosition storage user) internal view returns (uint256) {
        uint256 collateralUsd = oracle.getETHValueInUSD(user.deposited);
        uint256 debt = user.borrowed + _calculateInterest(user);
        uint256 debtUsd = oracle.getETHValueInUSD(debt);

        return riskEngine.healthFactor(collateralUsd, debtUsd);
    }

    function _revertIfHealthy(UserAssetPosition storage user) internal view {
        uint256 HF = _healthFactor(user);

        if (!riskEngine.isLiquidatable(HF)) {
            revert Lending__HealthFactorOk();
        }
    }

    function _calculateMaxLiquidation(uint256 debt) internal view returns (uint256) {
        return liquidationEngine.calculateMaxLiquidation(debt);
    }

    function _validateAsset(address asset) internal view {
        if (address(assetRegistry) == address(0)) {
            revert Lending__InvalidAssetRegistry();
        }

        if (!assetRegistry.isRegistered(asset)) {
            revert Lending__AssetNotRegistered();
        }

        (,, bool enabled) = assetRegistry.assets(asset);

        if (!enabled) revert Lending__AssetDisabled();
    }

    function _initReserveIfNeeded(address asset) internal {
        ReserveData storage reserve = reserves[asset];

        if (reserve.borrowIndex != 0) return;

        reserve.borrowIndex = PRECISION;
        reserve.liquidityIndex = PRECISION;

        emit ReserveInitialized(asset, reserve.borrowIndex, reserve.liquidityIndex);
    }

    function _addCollateralAsset(address user, address asset) internal {
        if (_isInCollateralList[user][asset]) return;

        _isInCollateralList[user][asset] = true;
        _userCollateralAssets[user].push(asset);

        emit CollateralAssetAdded(user, asset);
    }

    function _addDebtAsset(address user, address asset) internal {
        if (_isInDebtList[user][asset]) return;

        _isInDebtList[user][asset] = true;
        _userDebtAssets[user].push(asset);

        emit DebtAssetAdded(user, asset);
    }

    function _removeCollateralAssetIfZero(address user, address asset) internal {
        if (userPositions[user][asset].deposited != 0) return;

        if (!_isInCollateralList[user][asset]) return;

        address[] storage assets = _userCollateralAssets[user];

        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == asset) {
                assets[i] = assets[assets.length - 1];
                assets.pop();
                break;
            }
        }

        _isInCollateralList[user][asset] = false;

        emit CollateralAssetRemoved(user, asset);
    }

    function _removeDebtAssetIfZero(address user, address asset) internal {
        if (userPositions[user][asset].borrowed != 0) return;

        if (!_isInDebtList[user][asset]) return;

        address[] storage assets = _userDebtAssets[user];

        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == asset) {
                assets[i] = assets[assets.length - 1];
                assets.pop();
                break;
            }
        }

        _isInDebtList[user][asset] = false;

        emit DebtAssetRemoved(user, asset);
    }

    ////////////////////////////////
    ///// GETTERS FUNCTIONS /////
    ///////////////////////////////

    function calculateInterest(address userAddress, address asset) public view returns (uint256) {
        UserAssetPosition storage user = userPositions[userAddress][asset];

        return _calculateInterest(user);
    }

    function getTotalDebt(address userAddress, address asset) public view returns (uint256) {
        UserAssetPosition storage user = userPositions[userAddress][asset];

        uint256 interest = _calculateInterest(user);

        return user.borrowed + interest;
    }

    function getBalance(address user, address asset) public view returns (uint256) {
        return userPositions[user][asset].deposited;
    }

    function getHealthFactor(address userAddress, address asset) public view returns (uint256) {
        UserAssetPosition storage user = userPositions[userAddress][asset];

        return _healthFactor(user);
    }

    function getUserDeposit(address user, address asset) external view returns (uint256) {
        return userPositions[user][asset].deposited;
    }
}
