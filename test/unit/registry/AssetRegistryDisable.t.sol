// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RegistryTestBase} from "../../utils/RegistryTestBase.t.sol";
import {AssetRegistry} from "../../../src/registry/AssetRegistry.sol";

contract AssetRegistryDisableTest is RegistryTestBase {
    function testDisableAsset() public {
        _registerWeth();

        _enableAsset(weth);

        _disableAsset(weth);

        (,, bool enabled) = registry.assets(weth);

        assertFalse(enabled);
    }

    function testDisableRevertsIfAssetNotRegistered() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__AssetNotRegistered.selector);

        _disableAsset(usdc);
    }

    function testDisableRevertsIfAlreadyDisabled() public {
        _registerWeth();

        vm.expectRevert(AssetRegistry.AssetRegistry__AssetAlreadyDisabled.selector);

        _disableAsset(weth);
    }

    function testGuardianCanDisable() public {
        _registerWeth();

        _enableAsset(weth);

        vm.prank(guardian);

        registry.disableAsset(weth);

        (,, bool enabled) = registry.assets(weth);

        assertFalse(enabled);
    }

    function testRevertsIfNonGuardianCanDisable() public {
        _registerWeth();

        _enableAsset(weth);

        vm.prank(attacker);

        vm.expectRevert(AssetRegistry.AssetRegistry__NotGuardian.selector);

        registry.disableAsset(weth);
    }

    function testDisableEmitsEvent() public {
        _registerWeth();

        _enableAsset(weth);

        vm.expectEmit(true, false, false, false);

        emit AssetRegistry.AssetDisabled(weth, guardian);

        _disableAsset(weth);
    }
}
