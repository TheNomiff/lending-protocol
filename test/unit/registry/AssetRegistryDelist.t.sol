// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RegistryTestBase} from "../../utils/RegistryTestBase.t.sol";
import {AssetRegistry} from "../../../src/registry/AssetRegistry.sol";

contract AssetRegistryDelistTest is RegistryTestBase {
    function testDelistAsset() public {
        _registerWeth();

        _delistAsset(weth);

        assertFalse(registry.isRegistered(weth));
        assertEq(registry.assetCount(), 0);
    }

    function testCannotDelistUnregisteredAsset() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__AssetNotRegistered.selector);

        _delistAsset(weth);
    }

    function testOnlyTimelockCanDelist() public {
        _registerWeth();

        vm.expectRevert(AssetRegistry.AssetRegistry__NotTimelock.selector);
        vm.prank(attacker);

        registry.delistAsset(weth);
    }

    function testDelistUpdatesAssetList() public {
        _registerWeth();

        vm.prank(timelock);

        registry.registerAsset(usdc, AssetRegistry.AssetType.CollateralOnly, 6);

        _delistAsset(weth);

        assertEq(registry.assetCount(), 1);
        assertEq(registry.assetList(0), usdc);
    }

    function testDelistEmitsEvent() public {
        _registerWeth();

        vm.expectEmit(true, false, false, false);

        emit AssetRegistry.AssetDelisted(weth);

        _delistAsset(weth);
    }
}
