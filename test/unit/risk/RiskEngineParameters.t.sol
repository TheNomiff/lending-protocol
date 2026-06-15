// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskEngine} from "../../../src/engines/RiskEngine.sol";
import {RiskTestBase} from "../../utils/RiskTestBase.t.sol";
import {LiquidationEngine} from "../../../src/engines/LiquidationEngine.sol";

contract RiskEngineParametersTest is RiskTestBase {
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

    function testUpdateCloseFactor() public {
        uint256 newFactor = 75;
        liquidationEngine.updateCloseFactor(newFactor);

        assertEq(liquidationEngine.closeFactor(), newFactor);
    }

    function testUpdateCloseFactorRevertsIfZero() public {
        uint256 newFactor = 0;

        vm.expectRevert(LiquidationEngine.LiquidationEngine__InvalidCloseFactor.selector);

        liquidationEngine.updateCloseFactor(newFactor);
    }

    function testUpdateCloseFactorRevertsIfAbove100() public {
        uint256 newFactor = 101;

        vm.expectRevert(LiquidationEngine.LiquidationEngine__InvalidCloseFactor.selector);

        liquidationEngine.updateCloseFactor(newFactor);
    }

    function testNonOwnerCannotUpdateCloseFactor() public {
        uint256 newFactor = 75;
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(LiquidationEngine.LiquidationEngine__NotOwner.selector);

        liquidationEngine.updateCloseFactor(newFactor);
    }

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

    function testUpdateBonus() public {
        uint256 newBonus = 15;
        liquidationEngine.updateLiquidationBonus(newBonus);

        assertEq(liquidationEngine.liquidationBonus(), newBonus);
    }

    function testUpdateBonusRevertsIfZero() public {
        uint256 newBonus = 0;

        vm.expectRevert(LiquidationEngine.LiquidationEngine__InvalidBonus.selector);

        liquidationEngine.updateLiquidationBonus(newBonus);
    }

    function testUpdateBonusRevertsIfAbove100() public {
        uint256 newBonus = 101;

        vm.expectRevert(LiquidationEngine.LiquidationEngine__InvalidBonus.selector);

        liquidationEngine.updateLiquidationBonus(newBonus);
    }

    function testNonOwnerCannotUpdateBonus() public {
        uint256 newBonus = 15;
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(LiquidationEngine.LiquidationEngine__NotOwner.selector);

        liquidationEngine.updateLiquidationBonus(newBonus);
    }

    function testUpdateMaxBorrowRatioRevertsIfAboveOrEqualThreshold() public {
        vm.expectRevert(RiskEngine.RiskEngine__InvalidRiskParameters.selector);

        riskEngine.updateMaxBorrowRatio(80);
    }

    function testUpdateThresholdRevertsIfBelowOrEqualMaxBorrowRatio() public {
        vm.expectRevert(RiskEngine.RiskEngine__ValueUnchanged.selector);

        riskEngine.updateLiquidationThreshold(75);
    }

    function testUpdateThresholdRevertsIfBelowMaxBorrowRatio() public {
        uint256 currentMaxBorrowRatio = riskEngine.maxBorrowRatio();

        vm.expectRevert(RiskEngine.RiskEngine__InvalidRiskParameters.selector);

        riskEngine.updateLiquidationThreshold(currentMaxBorrowRatio - 1);
    }

    function testUpdateMaxBorrowRatioRevertsIfValueUnchanged() public {
        uint256 current = riskEngine.maxBorrowRatio();

        vm.expectRevert(RiskEngine.RiskEngine__ValueUnchanged.selector);

        riskEngine.updateMaxBorrowRatio(current);
    }

    function testUpdateThresholdRevertsIfValueUnchanged() public {
        uint256 current = riskEngine.liquidationThreshold();

        vm.expectRevert(RiskEngine.RiskEngine__ValueUnchanged.selector);

        riskEngine.updateLiquidationThreshold(current);
    }

    function testUpdateCloseFactorRevertsIfValueUnchanged() public {
        uint256 current = liquidationEngine.closeFactor();

        vm.expectRevert(LiquidationEngine.LiquidationEngine__ValueUnchanged.selector);

        liquidationEngine.updateCloseFactor(current);
    }

    function testUpdateHealthFactorRevertsIfValueUnchanged() public {
        uint256 current = riskEngine.minHealthFactor();

        vm.expectRevert(RiskEngine.RiskEngine__ValueUnchanged.selector);

        riskEngine.updateMinimumHealthFactor(current);
    }

    function testUpdateBonusRevertsIfValueUnchanged() public {
        uint256 current = liquidationEngine.liquidationBonus();

        vm.expectRevert(LiquidationEngine.LiquidationEngine__ValueUnchanged.selector);

        liquidationEngine.updateLiquidationBonus(current);
    }

    function testUpdateSupplyCapRevertsIfValueUnchanged() public {
        uint256 current = riskEngine.supplyCap();

        vm.expectRevert(RiskEngine.RiskEngine__ValueUnchanged.selector);

        riskEngine.updateSupplyCap(current);
    }

    function testUpdateBorrowCapRevertsIfValueUnchanged() public {
        uint256 current = riskEngine.borrowCap();

        vm.expectRevert(RiskEngine.RiskEngine__ValueUnchanged.selector);

        riskEngine.updateBorrowCap(current);
    }
}
