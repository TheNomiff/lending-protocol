// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RegistryTestBase} from "../../utils/RegistryTestBase.t.sol";
import {AssetRegistry} from "../../../src/registry/AssetRegistry.sol";
import {console} from "forge-std/console.sol";

contract AssetRegistryOwnerTest is RegistryTestBase {
    /////////////////////
    //// OWNERSHIP ////
    /////////////////////

    function testTransferOwnershipSetsPendingOwner() public {
        _transferOwnership(pendingOwner);

        assertEq(registry.pendingOwner(), pendingOwner);
    }

    function testAcceptOwnership() public {
        _transferOwnership(pendingOwner);
        _acceptOwnership(pendingOwner);

        assertEq(registry.owner(), pendingOwner);
    }

    function testOldOwnerRemovedAfterAccept() public {
        address newOwner = makeAddr("newOwner");
        address oldOwner = registry.owner();

        vm.assume(newOwner != oldOwner);

        _transferOwnership(newOwner);
        _acceptOwnership(newOwner);

        assertNotEq(oldOwner, registry.owner());
        assertEq(registry.owner(), newOwner);
    }

    function testCannotTransferOwnershipToZeroAddress() public {
        address newOwner = address(0);

        vm.expectRevert(AssetRegistry.AssetRegistry__InvalidOwner.selector);

        _transferOwnership(newOwner);
    }

    function testOnlyOwnerCanTransferOwnership() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__NotOwner.selector);
        vm.prank(attacker);

        _transferOwnership(pendingOwner);
    }

    function testOnlyPendingOwnerCanAcceptOwnership() public {
        _transferOwnership(pendingOwner);

        vm.expectRevert(AssetRegistry.AssetRegistry__NotPendingOwner.selector);

        _acceptOwnership(attacker);
    }

    ////////////////////////
    //// GUARDIANSHIP ////
    ////////////////////////

    function testSetGuardian() public {
        address newGuardian = makeAddr("newGuardian");

        _transferGuardian(newGuardian);

        assertEq(registry.guardian(), newGuardian);
    }

    function testCannotSetZeroGuardian() public {
        address newGuardian = address(0);

        vm.expectRevert(AssetRegistry.AssetRegistry__InvalidGuardian.selector);

        _transferGuardian(newGuardian);
    }

    function testOnlyOwnerCanSetGuardian() public {
        address newGuardian = makeAddr("newGuardian");

        vm.expectRevert(AssetRegistry.AssetRegistry__NotOwner.selector);
        vm.prank(attacker);

        _transferGuardian(newGuardian);
    }

    function testSetGuardianEmitsEvent() public {
        address newGuardian = makeAddr("newGuardian");

        address oldGuardian = registry.guardian();

        vm.expectEmit(true, true, false, false);

        emit AssetRegistry.GuardianUpdated(oldGuardian, newGuardian);

        _transferGuardian(newGuardian);
    }

    /////////////////////
    //// TIMELOCK /////
    /////////////////////

    function testSetTimelock() public {
        address newTimelock = makeAddr("timelock");

        _transferTimelock(newTimelock);

        assertEq(registry.timelock(), newTimelock);
    }

    function testCannotSetZeroTimelock() public {
        address newTimelock = address(0);

        vm.expectRevert(AssetRegistry.AssetRegistry__InvalidTimelock.selector);

        _transferTimelock(newTimelock);
    }

    function testOnlyOwnerCanSetTimelock() public {
        address newTimelock = makeAddr("timelock");

        vm.expectRevert(AssetRegistry.AssetRegistry__NotOwner.selector);
        vm.prank(attacker);

        _transferTimelock(newTimelock);
    }

    function testSetTimelockEmitsEvent() public {
        address oldTimelock = registry.timelock();
        address newTimelock = makeAddr("newTimelock");

        vm.expectEmit(true, true, false, false);

        emit AssetRegistry.TimelockUpdated(oldTimelock, newTimelock);

        _transferTimelock(newTimelock);
    }
}
