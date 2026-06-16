// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LiquidationTestBase} from "../../utils/LiquidationTestBase.t.sol";

contract LiquidationEngineConstructorTest is LiquidationTestBase {
    function testConstructorSetsOwner() public view {
        assertEq(liquidationEngine.owner(), address(this));
    }
}
