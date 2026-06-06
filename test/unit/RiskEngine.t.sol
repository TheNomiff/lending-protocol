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

        bool canWithdraw = riskEngine.canWithdraw(remainingCollateralUsd, debtUsd);

        assertTrue(canWithdraw);
    }

    function testCanWithdrawReturnsFalse() public view {
        uint256 remainingCollateralUsd = 70 ether;
        uint256 debtUsd = 40 ether;

        bool canWithdraw = riskEngine.canWithdraw(remainingCollateralUsd, debtUsd);

        assertFalse(canWithdraw);
    }

    function testCanWithdrawAtExactLimit() public view {
        uint256 remainingCollateralUsd = 100 ether;
        uint256 debtUsd = 50 ether;

        bool canWithdraw = riskEngine.canWithdraw(remainingCollateralUsd, debtUsd);

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
        uint256 expectedSeized =
            repayAmount + ((repayAmount * riskEngine.liquidationBonus())) / riskEngine.LIQUIDATION_PRECISION();
        uint256 seizedCollateral = riskEngine.calculateSeizedCollateral(repayAmount);

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

    ////////////////////////////////////
    ///// MAX BORROW RATIO TESTS /////
    ///////////////////////////////////

    function testUpdateMaxBorrowRatio() public {
        uint256 newRatio = 65;

        riskEngine.updateMaxBorrowRatio(newRatio);

        assertEq(riskEngine.maxBorrowRatio(), newRatio);
    }

    function testUpdateMaxBorrowRatioRevertsIfZero() public {
        uint256 newRatio = 0;

        vm.expectRevert(RiskEngine.RiskEngine__InvalidRatio.selector);

        riskEngine.updateMaxBorrowRatio(newRatio);
    }

    function testUpdateMaxBorrowRatioRevertsIfAbove100() public {
        uint256 newRatio = 101;

        vm.expectRevert(RiskEngine.RiskEngine__InvalidRatio.selector);

        riskEngine.updateMaxBorrowRatio(newRatio);
    }

    function testNonOwnerCannotUpdateMaxBorrowRatio() public {
        uint256 newRatio = 75;
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__NotOwner.selector);

        riskEngine.updateMaxBorrowRatio(newRatio);
    }

    /////////////////////////////
    ///// THRESHOLD TESTS /////
    ////////////////////////////

    function testUpdateThreshold() public {
        uint256 newThreshold = 80;
        riskEngine.updateLiquidationThreshold(newThreshold);

        assertEq(riskEngine.liquidationThreshold(), newThreshold);
    }

    function testUpdateThresholdRevertsIfZero() public {
        uint256 newThreshold = 0;

        vm.expectRevert(RiskEngine.RiskEngine__InvalidThreshold.selector);

        riskEngine.updateLiquidationThreshold(newThreshold);
    }

    function testUpdateThresholdRevertsIfAbove100() public {
        uint256 newThreshold = 101;

        vm.expectRevert(RiskEngine.RiskEngine__InvalidThreshold.selector);

        riskEngine.updateLiquidationThreshold(newThreshold);
    }

    function testNonOwnerCannotUpdateThreshold() public {
        uint256 newThreshold = 0;
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__NotOwner.selector);

        riskEngine.updateLiquidationThreshold(newThreshold);
    }

    ////////////////////////////////
    ///// CLOSE FACTOR TESTS /////
    ///////////////////////////////

    function testUpdateCloseFactor() public {
        uint256 newFactor = 75;
        riskEngine.updateCloseFactor(newFactor);

        assertEq(riskEngine.closeFactor(), newFactor);
    }

    function testUpdateCloseFactorRevertsIfZero() public {
        uint256 newFactor = 0;

        vm.expectRevert(RiskEngine.RiskEngine__InvalidCloseFactor.selector);

        riskEngine.updateCloseFactor(newFactor);
    }

    function testUpdateCloseFactorRevertsIfAbove100() public {
        uint256 newFactor = 101;

        vm.expectRevert(RiskEngine.RiskEngine__InvalidCloseFactor.selector);

        riskEngine.updateCloseFactor(newFactor);
    }

    function testNonOwnerCannotUpdateCloseFactor() public {
        uint256 newFactor = 75;
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__NotOwner.selector);

        riskEngine.updateCloseFactor(newFactor);
    }

    /////////////////////////////////////
    ///// MIN HEALTH FACTOR TESTS /////
    ////////////////////////////////////

    function testUpdateHealthFactor() public {
        uint256 newFactor = 2e18;

        riskEngine.updateMinimumHealthFactor(newFactor);

        assertEq(riskEngine.minHealthFactor(), newFactor);
    }

    function testUpdateHealthFactorRevertsIfZero() public {
        uint256 newFactor = 0;

        vm.expectRevert(RiskEngine.RiskEngine__InvalidHealthFactor.selector);

        riskEngine.updateMinimumHealthFactor(newFactor);
    }

    function testNonOwnerCannotUpdateHealthFactor() public {
        uint256 newFactor = 2e18;
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__NotOwner.selector);

        riskEngine.updateMinimumHealthFactor(newFactor);
    }

    /////////////////////////
    ///// BONUS TESTS /////
    ////////////////////////

    function testUpdateBonus() public {
        uint256 newBonus = 15;
        riskEngine.updateLiquidationBonus(newBonus);

        assertEq(riskEngine.liquidationBonus(), newBonus);
    }

    function testUpdateBonusRevertsIfZero() public {
        uint256 newBonus = 0;

        vm.expectRevert(RiskEngine.RiskEngine__InvalidBonus.selector);

        riskEngine.updateLiquidationBonus(newBonus);
    }

    function testUpdateBonusRevertsIfAbove100() public {
        uint256 newBonus = 101;

        vm.expectRevert(RiskEngine.RiskEngine__InvalidBonus.selector);

        riskEngine.updateLiquidationBonus(newBonus);
    }

    function testNonOwnerCannotUpdateBonus() public {
        uint256 newBonus = 15;
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__NotOwner.selector);

        riskEngine.updateLiquidationBonus(newBonus);
    }

    ////////////////////////////
    ///// GUARDIAN TESTS /////
    ///////////////////////////

    function testOwnerCanTransferGuardian() public {
        address newGuardian = makeAddr("New Guardian");

        riskEngine.transferGuardian(newGuardian);

        assertEq(riskEngine.guardian(), newGuardian);
    }

    function testNonOwnerCannotTransferGuardian() public {
        address newGuardian = makeAddr("New Guardian");
        address attacker = makeAddr("Attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__NotOwner.selector);
        riskEngine.transferGuardian(newGuardian);
    }

    function testNewGuardianCanPauseAndOldGuardianCannot() public {
        address newGuardian = makeAddr("New Guardian");

        riskEngine.transferGuardian(newGuardian);

        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);
        riskEngine.pauseBorrowing();

        vm.prank(newGuardian);
        riskEngine.pauseBorrowing();
        assertTrue(riskEngine.borrowPaused());
    }

    //////////////////////////////////////////
    ///// BORROW PAUSE & UNPAUSE TESTS /////
    /////////////////////////////////////////

    function testGuardianCanPauseBorrow() public {
        bool beforeState = riskEngine.borrowPaused();

        riskEngine.pauseBorrowing();

        bool afterState = riskEngine.borrowPaused();

        assertFalse(beforeState);
        assertTrue(afterState);
    }

    function testGuardianCanUnpauseBorrow() public {
        riskEngine.pauseBorrowing();
        bool beforeState = riskEngine.borrowPaused();

        riskEngine.unpauseBorrowing();
        bool afterState = riskEngine.borrowPaused();

        assertTrue(beforeState);
        assertFalse(afterState);
    }

    function testNonGuardianCannotPauseBorrow() public {
        address attacker = makeAddr("Attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);

        riskEngine.pauseBorrowing();
    }

    function testNonGuardianCannotUnpauseBorrow() public {
        riskEngine.pauseBorrowing();

        address attacker = makeAddr("Attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);

        riskEngine.unpauseBorrowing();
    }

    ///////////////////////////////////////////
    ///// DEPOSIT PAUSE & UNPAUSE TESTS /////
    //////////////////////////////////////////

    function testGuardianCanPauseDeposit() public {
        bool beforeState = riskEngine.depositPaused();

        riskEngine.pauseDepositing();

        bool afterState = riskEngine.depositPaused();

        assertFalse(beforeState);
        assertTrue(afterState);
    }

    function testGuardianCanUnpauseDeposit() public {
        riskEngine.pauseDepositing();
        bool beforeState = riskEngine.depositPaused();

        riskEngine.unpauseDepositing();
        bool afterState = riskEngine.depositPaused();

        assertTrue(beforeState);
        assertFalse(afterState);
    }

    function testNonGuardianCannotPauseDeposit() public {
        address attacker = makeAddr("Attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);

        riskEngine.pauseDepositing();
    }

    function testNonGuardianCannotUnpauseDeposit() public {
        riskEngine.pauseDepositing();

        address attacker = makeAddr("Attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);

        riskEngine.unpauseDepositing();
    }

    ////////////////////////////////////////////////
    ///// LIQUIDATION PAUSE & UNPAUSE TESTS /////
    //////////////////////////////////////////////

    function testGuardianCanPauseLiquidation() public {
        bool beforeState = riskEngine.liquidationPaused();

        riskEngine.pauseLiquidation();

        bool afterState = riskEngine.liquidationPaused();

        assertFalse(beforeState);
        assertTrue(afterState);
    }

    function testGuardianCanUnpauseLiquidation() public {
        riskEngine.pauseLiquidation();
        bool beforeState = riskEngine.liquidationPaused();

        riskEngine.unpauseLiquidation();
        bool afterState = riskEngine.liquidationPaused();

        assertTrue(beforeState);
        assertFalse(afterState);
    }

    function testNonGuardianCannotPauseLiquidation() public {
        address attacker = makeAddr("Attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);

        riskEngine.pauseLiquidation();
    }

    function testNonGuardianCannotUnpauseLiquidation() public {
        riskEngine.pauseLiquidation();

        address attacker = makeAddr("Attacker");

        vm.prank(attacker);

        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);
        riskEngine.unpauseLiquidation();
    }

    //////////////////////////
    ////// OWNER TESTS /////
    //////////////////////////

    function testOwnerCanTransferOwnership() public {
        address newOwner = makeAddr("New Owner");

        riskEngine.transferOwnership(newOwner);

        assertEq(riskEngine.owner(), newOwner);
    }

    function testNonOwnerCannotTransferOwnership() public {
        address newOwner = makeAddr("New Owner");
        address attacker = makeAddr("Attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__NotOwner.selector);

        riskEngine.transferOwnership(newOwner);
    }

    function testNewOwnerCanCallOwnerFunctions() public {
        address newOwner = makeAddr("New Owner");
        uint256 newThreshold = 80;

        riskEngine.transferOwnership(newOwner);

        vm.prank(newOwner);

        riskEngine.updateLiquidationThreshold(newThreshold);

        assertEq(riskEngine.owner(), newOwner);
        assertEq(riskEngine.liquidationThreshold(), newThreshold);
    }

    function testOldOwnerCannotCallOwnerFunctions() public {
        address oldOwner = address(this);
        address newOwner = makeAddr("New Owner");
        uint256 newBonus = 15;

        riskEngine.transferOwnership(newOwner);

        vm.prank(oldOwner);
        vm.expectRevert(RiskEngine.RiskEngine__NotOwner.selector);

        riskEngine.updateLiquidationBonus(newBonus);

        assertEq(riskEngine.owner(), newOwner);
    }

    function testTransferOwnershipToZeroAddressReverts() public {
        address newOwner = address(0);

        vm.expectRevert(RiskEngine.RiskEngine__InvalidOwner.selector);

        riskEngine.transferOwnership(newOwner);
    }

    /////////////////////////
    ///// PAUSE TESTS /////
    ////////////////////////

    function testBorrowPauseWorks() public {}

    function testDepositPauseWorks() public {}
}
