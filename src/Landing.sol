// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PriceOracle} from "../oracle/PriceOracle.sol";

contract Landing is ReentrancyGuard {
    ////////////////////
    ///// EVENTS /////
    ///////////////////

    event Deposited(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    event Withdrawn(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    event Borrowed(address indexed user, address indexed token, uint256 amount);

    event Repaid(address indexed user, address indexed token, uint256 amount);

    ////////////////////
    ///// ERRORS /////
    ///////////////////

    error Landing__AmountZero();
    error Landing__BorrowedFailed();
    error Landing__BorrowExceedsCollateral();
    error Landing__NotEnoughLiquidity();
    error Landing__InsufficientBalance();
    error Landing__NotAnyBorrow();
    error Landing__WithdrawnFailed();
    error Landing__RefundFailed();
    error Landing__InvalidOracle();
    error Landing__BreakHealthFactor();

    ////////////////////
    ///// ORACLE /////
    ///////////////////

    PriceOracle public oracle;

    /////////////////////////
    ///// CONSTRUCTOR /////
    ////////////////////////

    constructor(address _oracle) {
        if (_oracle == address(0)) revert Landing__InvalidOracle();

        oracle = PriceOracle(_oracle);

        owner = msg.sender;
    }

    ////////////////////
    ///// STRUCT /////
    ///////////////////

    struct User {
        uint256 deposited;
        uint256 borrowed;
        uint256 lastBorrowTimestamp;
    }

    //////////////////////
    ///// MAPPINGS /////
    /////////////////////

    mapping(address => User) public users;

    ////////////////////////////
    ///// STATE VARIABLE /////
    ////////////////////////////

    address public immutable owner;
    uint256 public totalLiquidity;
    uint256 public constant INTEREST_RATE = 5e16;
    uint256 public constant INTEREST_RATE_PER_SECOND = INTEREST_RATE / 365 days;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    ///////////////////////
    ///// MODIFIERS /////
    //////////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) revert Landing__AmountZero();
        _;
    }

    ////////////////////////////////
    ///// EXTERNAL FUNCTIONS /////
    ///////////////////////////////

    function deposit() external payable nonReentrant {
        if (msg.value == 0) revert Landing__AmountZero();

        User storage user = users[msg.sender];

        user.deposited += msg.value;
        totalLiquidity += msg.value;

        emit Deposited(msg.sender, address(0), msg.value);
    }

    function borrow(uint256 amount) external nonReentrant moreThanZero(amount) {
        User storage user = users[msg.sender];

        _accrueInterest(user);

        uint256 collateralUsd = oracle.getETHValueInUSD(user.deposited);
        uint256 maxBorrowUsd = collateralUsd / 2;
        uint256 borrowUsd = oracle.getETHValueInUSD(amount);
        uint256 currentDebt = oracle.getETHValueInUSD(user.borrowed);
        uint256 totalDebt = currentDebt + borrowUsd;

        if (totalDebt > maxBorrowUsd) revert Landing__BorrowExceedsCollateral();

        if (amount > totalLiquidity) revert Landing__NotEnoughLiquidity();

        user.borrowed += amount;
        user.lastBorrowTimestamp = block.timestamp;
        totalLiquidity -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert Landing__BorrowedFailed();

        emit Borrowed(msg.sender, address(0), amount);
    }

    function withdraw(
        uint256 amount
    ) external nonReentrant moreThanZero(amount) {
        User storage user = users[msg.sender];

        uint256 currentBalance = user.deposited;

        if (currentBalance < amount) revert Landing__InsufficientBalance();

        _accrueInterest(user);

        uint256 remainingCollateral = currentBalance - amount;
        uint256 remainingCollateralUsd = oracle.getETHValueInUSD(
            remainingCollateral
        );
        uint256 debtUsd = oracle.getETHValueInUSD(user.borrowed);
        uint256 maxBorrowUsd = remainingCollateralUsd / 2;

        if (debtUsd > maxBorrowUsd) {
            revert Landing__BorrowExceedsCollateral();
        }

        user.deposited = remainingCollateral;
        totalLiquidity -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert Landing__WithdrawnFailed();

        emit Withdrawn(msg.sender, address(0), amount);
    }

    function repay() external payable nonReentrant {
        User storage user = users[msg.sender];

        if (msg.value == 0) revert Landing__AmountZero();

        _accrueInterest(user);

        uint256 userDebt = user.borrowed;
        if (userDebt == 0) revert Landing__NotAnyBorrow();

        uint256 repayAmount = msg.value;

        if (repayAmount > userDebt) {
            repayAmount = userDebt;
        }

        uint256 extra = msg.value - repayAmount;

        user.borrowed -= repayAmount;

        if (user.borrowed == 0) {
            user.lastBorrowTimestamp = 0;
        }

        totalLiquidity += repayAmount;

        if (extra > 0) {
            (bool success, ) = payable(msg.sender).call{value: extra}("");
            if (!success) revert Landing__RefundFailed();
        }

        emit Repaid(msg.sender, address(0), repayAmount);
    }

    ////////////////////////////////
    ///// GETTERS FUNCTIONS /////
    ///////////////////////////////

    function calculateInterest(
        address userAddress
    ) public view returns (uint256) {
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

    ////////////////////////////////
    ///// INTERNAL FUNCTIONS /////
    ///////////////////////////////

    function _calculateInterest(
        User storage user
    ) internal view returns (uint256) {
        if (user.borrowed == 0 || user.lastBorrowTimestamp == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - user.lastBorrowTimestamp;

        return
            (user.borrowed * INTEREST_RATE_PER_SECOND * timeElapsed) /
            PRECISION;
    }

    function _accrueInterest(User storage user) internal {
        uint256 interest = _calculateInterest(user);

        if (interest > 0) {
            user.borrowed += interest;
        }

        if (user.borrowed > 0) {
            user.lastBorrowTimestamp = block.timestamp;
        }
    }

    function _healthFactor(User storage user) internal view returns (uint256) {
        uint256 collateralUsd = oracle.getETHValueInUSD(user.deposited);
        uint256 debt = user.borrowed + _calculateInterest(user);
        uint256 debtUsd = oracle.getETHValueInUSD(debt);

        if (debtUsd == 0) {
            return type(uint256).max;
        }

        uint256 collateralAdjusted = (collateralUsd * LIQUIDATION_THRESHOLD) /
            LIQUIDATION_PRECISION;

        return (collateralAdjusted * PRECISION) / debtUsd;
    }
}
