// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RegistryTestBase} from "../../utils/RegistryTestBase.t.sol";
import {AssetRegistry} from "../../../src/registry/AssetRegistry.sol";

contract AssetRegistryConstructorTest is RegistryTestBase {
    function testConstructorSetsOwner() public view {
        assertEq(registry.owner(), address(this));
    }

    function testConstructorSetsTimelock() public view {
        assertEq(registry.timelock(), timelock);
    }

    function testConstructorSetsGuardian() public view {
        assertEq(registry.guardian(), guardian);
    }

    function testConstructorRevertsIfZeroTimelock() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__InvalidTimelock.selector);

        new AssetRegistry(address(0), address(guardian));
    }

    function testConstructorRevertsIfZeroGuardian() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__InvalidGuardian.selector);

        new AssetRegistry(address(timelock), address(0));
    }
}
