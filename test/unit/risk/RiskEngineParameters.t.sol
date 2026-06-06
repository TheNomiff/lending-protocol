// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskEngine} from "../../../src/engines/RiskEngine.sol";
import {RiskTestBase} from "../../utils/RiskTestBase.t.sol";

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
}
