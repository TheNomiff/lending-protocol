// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskEngine} from "../../src/engines/RiskEngine.sol";
import {RiskTestBase} from "../utils/RiskTestBase.t.sol";
import {console} from "forge-std/console.sol";

contract RiskEngineTest is RiskTestBase {
    //////////////////////////////////
    ////// CONSTRUCTOR TESTS ////////
    //////////////////////////////////

    function testConstructorSetsOwner() public view {
        assertEq(riskEngine.owner(), address(this));
    }

    function testConstructorSetsGuardian() public view {
        assertEq(riskEngine.guardian(), address(this));
    }

    function testConstructorSetsCaps() public view {
        assertEq(riskEngine.supplyCap(), SUPPLY_CAP);
        assertEq(riskEngine.borrowCap(), BORROW_CAP);
    }

    function testConstructorRevertsIfSupplyCapZero() public {
        vm.expectRevert(RiskEngine.RiskEngine__InvalidCaps.selector);

        new RiskEngine(0, BORROW_CAP);
    }

    function testConstructorRevertsIfBorrowCapZero() public {
        vm.expectRevert(RiskEngine.RiskEngine__InvalidCaps.selector);

        new RiskEngine(SUPPLY_CAP, 0);
    }

    function testConstructorRevertsIfBorrowCapExceedsSupplyCap() public {
        vm.expectRevert(RiskEngine.RiskEngine__InvalidCaps.selector);

        new RiskEngine(100 ether, 200 ether);
    }

    //////////////////////////////////
    ////// HEALTH FACTOR TESTS //////
    //////////////////////////////////

    function testHealthFactorReturnsMaxWhenDebtZero() public view {
        uint256 HF = riskEngine.healthFactor(100 ether, 0);
        assertEq(HF, type(uint256).max);
    }

    function testHealthFactorCalculationDynamic() public view {
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 30 ether;

        uint256 expectedCollateral = (collateralUsd *
            riskEngine.liquidationThreshold()) /
            riskEngine.LIQUIDATION_PRECISION();
        uint256 expectedHF = (expectedCollateral * riskEngine.PRECISION()) /
            debtUsd;

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

    //////////////////////////////////
    ////// BORROW TESTS /////////////
    //////////////////////////////////

    function testCanBorrowReturnsTrue() public view {
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 30 ether;

        bool canBorrow = riskEngine.canBorrow(collateralUsd, debtUsd);

        assertTrue(canBorrow);
        assertEq(riskEngine.maxBorrow(collateralUsd), 50 ether);
    }

    function testCanBorrowReturnsFalse() public view {
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 60 ether;

        bool canBorrow = riskEngine.canBorrow(collateralUsd, debtUsd);

        assertFalse(canBorrow);
        assertEq(riskEngine.maxBorrow(collateralUsd), 50 ether);
    }

    function testCanBorrowAtExactLimit() public view {
        uint256 collateralUsd = 100 ether;
        uint256 debtUsd = 50 ether;

        uint256 maxBorrow = riskEngine.maxBorrow(collateralUsd);
        bool canBorrow = riskEngine.canBorrow(collateralUsd, debtUsd);

        assertTrue(canBorrow);
        assertEq(riskEngine.maxBorrow(collateralUsd), 50 ether);
        assert(debtUsd == maxBorrow);
    }

    //////////////////////////////////
    ////// WITHDRAW TESTS ///////////
    //////////////////////////////////

    function testCanWithdrawReturnsTrue() public view {
        uint256 remainingCollateralUsd = 90 ether;
        uint256 debtUsd = 40 ether;

        bool canWithdraw = riskEngine.canWithdraw(
            remainingCollateralUsd,
            debtUsd
        );

        assertTrue(canWithdraw);
    }

    function testCanWithdrawReturnsFalse() public view {
        uint256 remainingCollateralUsd = 70 ether;
        uint256 debtUsd = 40 ether;

        bool canWithdraw = riskEngine.canWithdraw(
            remainingCollateralUsd,
            debtUsd
        );

        assertFalse(canWithdraw);
    }

    function testCanWithdrawAtExactLimit() public view {
        uint256 remainingCollateralUsd = 100 ether;
        uint256 debtUsd = 50 ether;

        bool canWithdraw = riskEngine.canWithdraw(
            remainingCollateralUsd,
            debtUsd
        );

        assertTrue(canWithdraw);
    }

    //////////////////////////////////
    ////// LIQUIDATION TESTS ////////
    //////////////////////////////////

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
        uint256 maxLiquidation = riskEngine.calculateMaxLiquidation(debtUsd);

        assertEq(maxLiquidation, 20 ether);
    }

    function testCalculateSeizedCollateral() public view {
        uint256 repayAmount = 10 ether;
        uint256 expectedSeized = repayAmount +
            ((repayAmount * riskEngine.liquidationBonus())) /
            riskEngine.LIQUIDATION_PRECISION();
        uint256 seizedCollateral = riskEngine.calculateSeizedCollateral(
            repayAmount
        );

        assertEq(seizedCollateral, expectedSeized);
    }

    function testIsLiquidatableAtExactMinimumHealthFactor() public view {
        uint256 HF = riskEngine.minHealthFactor();

        assertFalse(riskEngine.isLiquidatable(HF));
    }

    ///////////////////////
    ///// CAP TESTS /////
    //////////////////////

    function testCanSupplyAtCap() public view {
        uint256 supplyAmount = riskEngine.supplyCap();
        bool canSupply = riskEngine.canSupply(0, supplyAmount);

        assertTrue(canSupply);
    }

    function testCanSupplyAboveCap() public view {
        uint256 supplyAmount = riskEngine.supplyCap() + 100 ether;
        bool canSupply = riskEngine.canSupply(0, supplyAmount);

        assertFalse(canSupply);
    }

    function testCanBorrowAtCap() public view {
        uint256 borrowCap = riskEngine.borrowCap();
        bool canBorrow = riskEngine.canGlobalBorrow(0, borrowCap);

        assertTrue(canBorrow);
    }

    function testCanBorrowAboveCap() public view {
        uint256 borrowCap = riskEngine.borrowCap() + 100 ether;
        bool canBorrow = riskEngine.canGlobalBorrow(0, borrowCap);

        assertFalse(canBorrow);
    }

    /////////////////////////////
    ///// PARAMETER TESTS /////
    ////////////////////////////

    function testUpdateThreshold() public {}

    function testUpdateBonus() public {}

    function testUpdateCloseFactor() public {}

    /////////////////////////
    ///// OWNER TESTS /////
    ////////////////////////

    function testOwnerCanUpdateBorrowRatio() public {}

    function testNonOwnerCannotUpdateBorrowRatio() public {}

    ////////////////////////////
    ///// GUARDIAN TESTS /////
    ///////////////////////////

    function testGuardianCanPauseBorrow() public {}

    function testGuardianCanPauseDeposit() public {}

    /////////////////////////
    ///// PAUSE TESTS /////
    ////////////////////////

    function testBorrowPauseWorks() public {}

    function testDepositPauseWorks() public {}
}
