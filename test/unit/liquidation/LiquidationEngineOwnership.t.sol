// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LiquidationEngine} from "../../../src/engines/LiquidationEngine.sol";
import {LiquidationTestBase} from "../../utils/LiquidationTestBase.t.sol";

contract LiquidationEngineOwnershipTest is LiquidationTestBase {
    function testOldOwnerCannotCallOwnerFunctions() public {
        address oldOwner = address(this);
        address newOwner = makeAddr("New Owner");
        uint256 newBonus = 15;

        liquidationEngine.transferOwnership(newOwner);

        vm.prank(oldOwner);
        vm.expectRevert(LiquidationEngine.LiquidationEngine__NotOwner.selector);

        liquidationEngine.updateLiquidationBonus(newBonus);

        assertEq(liquidationEngine.owner(), newOwner);
    }

    function testOwnerCanTransferOwnership() public {
        address newOwner = makeAddr("New Owner");

        liquidationEngine.transferOwnership(newOwner);

        assertEq(liquidationEngine.owner(), newOwner);
    }

    function testRevertsIfNonOwnerTransferOwnership() public {
        address nonOwner = address(999);

        vm.prank(nonOwner);
        vm.expectRevert(LiquidationEngine.LiquidationEngine__NotOwner.selector);

        liquidationEngine.transferOwnership(nonOwner);
    }

    function testTransferOwnershipToZeroAddressReverts() public {
        vm.expectRevert(LiquidationEngine.LiquidationEngine__InvalidOwner.selector);

        liquidationEngine.transferOwnership(address(0));
    }
}
