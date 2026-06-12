// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimelockTestBase} from "../../utils/TimelockTestBase.t.sol";

contract TimelockConstructorTest is TimelockTestBase {
    function testConstructorSetsOwner() public view {
        assertEq(timelock.owner(), address(this));
    }

    function testConstructorSetsTxCountToZero() public view {
        assertEq(timelock.txCount(), 0);
    }

    function testConstructorSetsDelayConstant() public view {
        assertEq(timelock.DELAY(), 1 days);
    }
}
