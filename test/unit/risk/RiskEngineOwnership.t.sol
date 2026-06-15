// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskEngine} from "../../../src/engines/RiskEngine.sol";
import {RiskTestBase} from "../../utils/RiskTestBase.t.sol";
import {LiquidationEngine} from "../../../src/engines/LiquidationEngine.sol";

contract RiskEngineOwnershipTest is RiskTestBase {
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

        liquidationEngine.transferOwnership(newOwner);

        vm.prank(oldOwner);
        vm.expectRevert(LiquidationEngine.LiquidationEngine__NotOwner.selector);

        liquidationEngine.updateLiquidationBonus(newBonus);

        assertEq(liquidationEngine.owner(), newOwner);
    }

    function testTransferOwnershipToZeroAddressReverts() public {
        address newOwner = address(0);

        vm.expectRevert(RiskEngine.RiskEngine__InvalidOwner.selector);

        riskEngine.transferOwnership(newOwner);
    }
}
