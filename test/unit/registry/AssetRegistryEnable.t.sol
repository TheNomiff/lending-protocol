// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RegistryTestBase} from "../../utils/RegistryTestBase.t.sol";
import {AssetRegistry} from "../../../src/registry/AssetRegistry.sol";

contract AssetRegistryEnableTest is RegistryTestBase {
    function testEnableAsset() public {
        _registerWeth();

        _enableAsset(weth);

        (,, bool enabled) = registry.assets(weth);

        assertTrue(enabled);
    }

    function testEnableRevertsIfAssetNotRegistered() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__AssetNotRegistered.selector);

        _enableAsset(weth);
    }

    function testEnableRevertsIfAlreadyEnabled() public {
        _registerWeth();

        _enableAsset(weth);

        vm.expectRevert(AssetRegistry.AssetRegistry__AssetAlreadyEnabled.selector);

        _enableAsset(weth);
    }

    function testTimelockCanEnable() public {
        _registerWeth();

        vm.prank(timelock);

        registry.enableAsset(weth);

        (,, bool enabled) = registry.assets(weth);

        assertTrue(enabled);
    }

    function testNonTimelockCannotEnable() public {
        _registerWeth();

        vm.prank(attacker);

        vm.expectRevert(AssetRegistry.AssetRegistry__NotTimelock.selector);

        registry.enableAsset(weth);
    }

    function testEnableEmitsEvent() public {
        _registerWeth();

        vm.expectEmit(true, false, false, false);

        emit AssetRegistry.AssetEnabled(weth);

        _enableAsset(weth);
    }
}
