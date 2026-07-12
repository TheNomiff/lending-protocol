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

    struct User {
        uint256 deposited;
        uint256 borrowed;
        uint256 lastBorrowTimestamp;
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

    ////////////////////
    ///// EVENTS /////
    ///////////////////

    event Deposited(address indexed user, address indexed token, uint256 amount);

    event Withdrawn(address indexed user, address indexed token, uint256 amount);

    event Borrowed(address indexed user, address indexed token, uint256 amount);

    event Repaid(address indexed user, address indexed token, uint256 amount);

    event Liquidated(address indexed liquidator, address indexed user, uint256 debtRepaid, uint256 collateralSeized);

    ////////////////////////////
    ///// STATE VARIABLE /////
    ////////////////////////////

    uint256 public totalLiquidity;
    uint256 public totalSupply;
    uint256 public totalBorrow;
    uint256 public constant INTEREST_RATE = 5e16;
    uint256 public constant INTEREST_RATE_PER_SECOND = INTEREST_RATE / 365 days;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_PRECISION = 100;

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

    mapping(address => User) public users;

    ///////////////////////
    ///// MODIFIERS /////
    //////////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) revert Lending__AmountZero();
        _;
    }

    /////////////////////////
    ///// CONSTRUCTOR /////
    ////////////////////////

    constructor(address _oracle, address riskEngineAddress) {
        if (_oracle == address(0)) revert Lending__InvalidOracle();
        oracle = PriceOracle(_oracle);

        if (riskEngineAddress == address(0)) {
            revert Lending__InvalidRiskEngine();
        }

        riskEngine = RiskEngine(riskEngineAddress);

        owner = msg.sender;
    }

    ////////////////////////////////
    ///// EXTERNAL FUNCTIONS /////
    ///////////////////////////////

    function deposit() external payable nonReentrant {
        if (riskEngine.depositPaused()) {
            revert Lending__DepositPaused();
        }

        if (msg.value == 0) revert Lending__AmountZero(); // Revert if the user tries to deposit 0 ETH.

        User storage user = users[msg.sender];

        if (!riskEngine.canSupply(totalSupply, msg.value)) {
            revert Lending__SupplyCapExceeded();
        }

        user.deposited += msg.value; // Accounting for the user's deposited amount, which will be used as collateral for borrowing.
        totalLiquidity += msg.value; // Total liquidity increases by the deposited amount, because the protocol can lend that amount to other users.
        totalSupply += msg.value;

        emit Deposited(msg.sender, address(0), msg.value);
    }

    function borrow(uint256 amount) external nonReentrant moreThanZero(amount) {
        if (riskEngine.borrowPaused()) {
            revert Lending__BorrowPaused();
        }

        User storage user = users[msg.sender];

        _accrueInterest(user);

        uint256 collateralUsd = oracle.getETHValueInUSD(user.deposited); // $1000
        uint256 borrowUsd = oracle.getETHValueInUSD(amount); // $200
        uint256 currentDebt = oracle.getETHValueInUSD(getTotalDebt(msg.sender)); // $0 default, but if the user already has a borrow, it will include the interest as well. for example, if the user has a borrow of $100 and the interest is $10, the currentDebt will be $110.
        uint256 totalDebt = currentDebt + borrowUsd; // $0 + $200 = $200, but if the user already has a borrow, it will be $110 + $200 = $300, and if the user has a borrow of $400, it will be $400 + $200 = $600, which exceeds the max borrow of $500 and reverts.

        if (!riskEngine.canBorrow(collateralUsd, totalDebt)) {
            revert Lending__BorrowExceedsCollateral();
        }

        if (!riskEngine.canGlobalBorrow(totalBorrow, amount)) {
            revert Lending__BorrowCapExceeded();
        }

        if (amount > totalLiquidity) revert Lending__NotEnoughLiquidity(); // $200 > totalLiquidity reverts, because the protocol doesn't have enough funds to Lend.

        user.borrowed += amount; // $200
        user.lastBorrowTimestamp = block.timestamp;
        totalLiquidity -= amount; // Total liqidity decreases by the borrow amount, because the protocol is Lending that amount to the user.
        totalBorrow += amount;

        // send the borrow amount to the user

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert Lending__BorrowedFailed();

        emit Borrowed(msg.sender, address(0), amount);
    }

    function withdraw(uint256 amount) external nonReentrant moreThanZero(amount) {
        User storage user = users[msg.sender];

        uint256 currentBalance = user.deposited; // Current balance of the user.

        if (currentBalance < amount) revert Lending__InsufficientBalance(); // Revert if the user tries to withdraw more than their deposited amount.

        _accrueInterest(user); // Accrue interest on the user's borrow before allowing them to withdraw, to ensure that the health factor is calculated correctly.

        uint256 remainingCollateral = currentBalance - amount; // find the amount of collateral that the user will have after the withdrawal, to check if the health factor is still above the minimum threshold.

        uint256 remainingCollateralUsd = oracle.getETHValueInUSD(remainingCollateral); // Get the USD value of the remaining collateral.

        uint256 debtUsd = oracle.getETHValueInUSD(getTotalDebt(msg.sender)); // Get the USD value of the user's debt, including the interest.

        if (!riskEngine.canWithdraw(remainingCollateralUsd, debtUsd)) {
            revert Lending__BorrowExceedsCollateral();
        }

        user.deposited = remainingCollateral;
        totalLiquidity -= amount;
        totalSupply -= amount;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert Lending__WithdrawnFailed();

        emit Withdrawn(msg.sender, address(0), amount);
    }

    function repay() external payable nonReentrant {
        User storage user = users[msg.sender];

        if (msg.value == 0) revert Lending__AmountZero();

        _accrueInterest(user);

        uint256 debt = user.borrowed;

        if (debt == 0) revert Lending__NotAnyBorrow();

        uint256 repayAmount = msg.value;

        if (repayAmount > debt) {
            repayAmount = debt;
        }

        uint256 extra = msg.value - repayAmount;

        user.borrowed = debt - repayAmount;

        if (user.borrowed == 0) {
            user.lastBorrowTimestamp = 0;
        }

        totalLiquidity += repayAmount;

        if (repayAmount >= totalBorrow) {
            totalBorrow = 0;
        } else {
            totalBorrow -= repayAmount;
        }

        if (extra > 0) {
            (bool success,) = payable(msg.sender).call{value: extra}("");

            if (!success) revert Lending__RefundFailed();
        }

        emit Repaid(msg.sender, address(0), repayAmount);
    }

    function liquidate(address userAddress) external payable nonReentrant moreThanZero(msg.value) {
        if (riskEngine.liquidationPaused()) {
            revert Lending__LiquidationPaused();
        }

        User storage user = users[userAddress];

        _accrueInterest(user); // Accrue interest on the user's borrow before allowing them to be liquidated.
        _revertIfHealthy(user); // Revert if the user's health factor is above the minimum threshold, which mean they are not eligible for liquidation.

        uint256 currentDebt = getTotalDebt(userAddress); // Total debt of the user, including the interest, that need to be repaid by the liquidator to reduce the user's debt and improve their health factor.
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
        totalLiquidity += repayAmount;
        totalBorrow -= repayAmount;

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

        uint256 endingHF = _healthFactor(user);

        if (endingHF <= startingHF) revert Lending__HealthFactorNotImproved();

        (bool sent,) = payable(msg.sender).call{value: collateralToSeize}("");
        if (!sent) revert Lending__LiquidationBonusFailed();

        emit Liquidated(msg.sender, userAddress, repayAmount, collateralToSeize);
    }

    ////////////////////////////////
    ///// INTERNAL FUNCTIONS /////
    ///////////////////////////////

    function _calculateInterest(User storage user) internal view returns (uint256) {
        if (user.borrowed == 0 || user.lastBorrowTimestamp == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - user.lastBorrowTimestamp;

        return (user.borrowed * INTEREST_RATE_PER_SECOND * timeElapsed) / PRECISION;
    }

    function _accrueInterest(User storage user) internal {
        uint256 interest = _calculateInterest(user);

        if (interest > 0) {
            user.borrowed += interest;
            totalBorrow += interest;
        }

        if (user.borrowed > 0) {
            user.lastBorrowTimestamp = block.timestamp;
        }
    }

    function _healthFactor(User storage user) internal view returns (uint256) {
        uint256 collateralUsd = oracle.getETHValueInUSD(user.deposited);
        uint256 debt = user.borrowed + _calculateInterest(user);
        uint256 debtUsd = oracle.getETHValueInUSD(debt);

        return riskEngine.healthFactor(collateralUsd, debtUsd);
    }

    function _revertIfHealthy(User storage user) internal view {
        uint256 HF = _healthFactor(user);

        if (!riskEngine.isLiquidatable(HF)) {
            revert Lending__HealthFactorOk();
        }
    }

    function _calculateMaxLiquidation(uint256 debt) internal view returns (uint256) {
        return liquidationEngine.calculateMaxLiquidation(debt);
    }

    function _validateAsset(address asset) internal view {
        if (!assetRegistry.isRegistered(asset)) {
            revert Lending__AssetNotRegistered();
        }

        (,, bool enabled) = assetRegistry.assets(asset);

        if (!enabled) revert Lending__AssetDisabled();
    }

    ////////////////////////////////
    ///// GETTERS FUNCTIONS /////
    ///////////////////////////////

    function calculateInterest(address userAddress) public view returns (uint256) {
        User storage user = users[userAddress];

        return _calculateInterest(user);
    }

    function getTotalDebt(address userAddress) public view returns (uint256) {
        User storage user = users[userAddress];

        uint256 interest = _calculateInterest(user);

        return user.borrowed + interest;
    }

    function getBalance(address userAddress) public view returns (uint256) {
        return users[userAddress].deposited;
    }

    function getHealthFactor(address userAddress) public view returns (uint256) {
        User storage user = users[userAddress];

        return _healthFactor(user);
    }
}
