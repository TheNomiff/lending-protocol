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

    function testCanWithdrawReturnsTrue() public {}

    function testCanWithdrawReturnsFalse() public {}

    //////////////////////////////////
    ////// LIQUIDATION TESTS ////////
    //////////////////////////////////

    function testIsLiquidatableReturnsTrue() public {}

    function testIsLiquidatableReturnsFalse() public {}

    function testCalculateMaxLiquidation() public {}

    function testCalculateSeizedCollateral() public {}
}
