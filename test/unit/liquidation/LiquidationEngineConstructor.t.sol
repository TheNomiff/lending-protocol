// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LiquidationTestBase} from "../../utils/LiquidationTestBase.t.sol";
import {LiquidationEngine} from "../../../src/engines/LiquidationEngine.sol";

contract LiquidationEngineConstructorTest is LiquidationTestBase {
    function testConstructorSetsOwner() public view {
        assertEq(liquidationEngine.owner(), address(this));
    }

    function testConstructorRevertsIfRiskEngineZeroAddress() public {
        vm.expectRevert(
            LiquidationEngine.LiquidationEngine__InvalidRiskEngine.selector
        );

        new LiquidationEngine(address(0));
    }
}
