// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RegistryTestBase} from "../../utils/RegistryTestBase.t.sol";
import {AssetRegistry} from "../../../src/registry/AssetRegistry.sol";

contract AssetRegistryPauseTest is RegistryTestBase {
    function testGuardianCanPause() public {
        _pauseRegistry();

        assertTrue(registry.registryPaused());
    }

    function testCannotPauseTwice() public {
        _pauseRegistry();

        vm.expectRevert(AssetRegistry.AssetRegistry__AlreadyPaused.selector);

        _pauseRegistry();
    }

    function testNonGuardianCannotPause() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__NotGuardian.selector);
        vm.prank(attacker);

        registry.pauseRegistry();
    }

    function testGuardianCanUnpause() public {
        _pauseRegistry();

        _unpauseRegistry();

        assertFalse(registry.registryPaused());
    }

    function testCannotUnpauseWhenNotPaused() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__NotPaused.selector);

        _unpauseRegistry();
    }

    function testNonGuardianCannotUnpause() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__NotGuardian.selector);
        vm.prank(attacker);

        registry.unpauseRegistry();
    }

    function testPauseEmitsEvent() public {
        vm.expectEmit(true, false, false, false);

        emit AssetRegistry.RegistryPaused(guardian);

        _pauseRegistry();
    }

    function testUnpauseEmitsEvent() public {
        _pauseRegistry();

        vm.expectEmit(true, false, false, false);

        emit AssetRegistry.RegistryUnpaused(guardian);

        _unpauseRegistry();
    }

    function testPausedRegistryBlocksRegister() public {
        _pauseRegistry();

        vm.expectRevert(AssetRegistry.AssetRegistry__RegistryPaused.selector);

        _registerWeth();
    }
}
