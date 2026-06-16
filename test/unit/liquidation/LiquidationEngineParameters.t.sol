// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LiquidationEngine} from "../../../src/engines/LiquidationEngine.sol";
import {LiquidationTestBase} from "../../utils/LiquidationTestBase.t.sol";

contract LiquidationEngineParametersTest is LiquidationTestBase {
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

    function testUpdateCloseFactorRevertsIfValueUnchanged() public {
        uint256 current = liquidationEngine.closeFactor();

        vm.expectRevert(LiquidationEngine.LiquidationEngine__ValueUnchanged.selector);

        liquidationEngine.updateCloseFactor(current);
    }

    function testUpdateBonusRevertsIfValueUnchanged() public {
        uint256 current = liquidationEngine.liquidationBonus();

        vm.expectRevert(LiquidationEngine.LiquidationEngine__ValueUnchanged.selector);

        liquidationEngine.updateLiquidationBonus(current);
    }
}
