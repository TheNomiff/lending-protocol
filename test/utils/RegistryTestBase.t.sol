// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AssetRegistry} from "../../src/registry/AssetRegistry.sol";

abstract contract RegistryTestBase is Test {
    AssetRegistry internal registry;

    address internal owner;
    address internal timelock;
    address internal guardian;
    address internal attacker;
    address internal pendingOwner;

    address internal weth;
    address internal usdc;

    function setUp() public virtual {
        owner = address(this);

        timelock = makeAddr("timelock");
        guardian = makeAddr("guardian");
        attacker = makeAddr("attacker");
        pendingOwner = makeAddr("pendingOwner");

        weth = makeAddr("WETH");
        usdc = makeAddr("USDC");

        registry = new AssetRegistry(address(timelock), address(guardian));
    }

    function _registerWeth() internal {
        vm.prank(timelock);

        registry.registerAsset(weth, AssetRegistry.AssetType.CollateralOnly, 18);
    }

    function _updateAsset(address asset, AssetRegistry.AssetType newType) internal {
        vm.prank(timelock);

        registry.updateAsset(asset, newType);
    }

    function _enableAsset(address asset) internal {
        vm.prank(timelock);

        registry.enableAsset(asset);
    }

    function _disableAsset(address asset) internal {
        vm.prank(guardian);

        registry.disableAsset(asset);
    }

    function _pauseRegistry() internal {
        vm.prank(guardian);

        registry.pauseRegistry();
    }

    function _unpauseRegistry() internal {
        vm.prank(guardian);

        registry.unpauseRegistry();
    }

    function _delistAsset(address asset) internal {
        vm.prank(timelock);

        registry.delistAsset(asset);
    }

    function _transferOwnership(address newOwner) internal {
        registry.transferOwnership(newOwner);
    }

    function _acceptOwnership(address sender) internal {
        vm.prank(sender);

        registry.acceptOwnership();
    }

    function _transferGuardian(address newGuardian) internal {
        registry.transferGuardian(newGuardian);
    }

    function _transferTimelock(address newTimelock) internal {
        registry.transferTimelock(newTimelock);
    }
}
