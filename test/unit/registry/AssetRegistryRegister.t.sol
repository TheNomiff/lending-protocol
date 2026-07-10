// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RegistryTestBase} from "../../utils/RegistryTestBase.t.sol";
import {AssetRegistry} from "../../../src/registry/AssetRegistry.sol";

contract AssetRegistryRegisterTest is RegistryTestBase {
    function testRegisterAsset() public {
        _registerWeth();

        (uint8 decimals, AssetRegistry.AssetType assetType, bool enabled) = registry.assets(weth);

        assertEq(decimals, 18);

        assertEq(uint256(assetType), uint256(AssetRegistry.AssetType.CollateralOnly));

        assertEq(enabled, false);

        assertEq(registry.isRegistered(weth), true);

        assertEq(registry.assetCount(), 1);

        assertEq(registry.assetList(0), weth);
    }

    function testCannotRegisterDuplicateAsset() public {
        _registerWeth();

        vm.expectRevert(AssetRegistry.AssetRegistry__AssetAlreadyRegistered.selector);

        _registerWeth();
    }

    function testRegisterRevertsIfZeroAddress() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__InvalidAsset.selector);
        vm.prank(timelock);

        registry.registerAsset(address(0), AssetRegistry.AssetType.CollateralOnly, 18);
    }

    function testRegisterRevertsIfInvalidDecimals() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__InvalidDecimals.selector);

        vm.prank(timelock);

        registry.registerAsset(weth, AssetRegistry.AssetType.CollateralOnly, 19);
    }

    function testRegisterRevertsIfInvalidAssetType() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__InvalidAssetType.selector);

        vm.prank(timelock);

        registry.registerAsset(weth, AssetRegistry.AssetType.None, 18);
    }

    function testRegisterStoresAssetConfig() public {
        _registerWeth();

        (uint8 decimals, AssetRegistry.AssetType assetType, bool enabled) = registry.assets(weth);

        assertEq(decimals, 18);
        assertEq(uint256(assetType), uint256(AssetRegistry.AssetType.CollateralOnly));
        assertFalse(enabled);
    }

    function testRegisterUpdatesAssetList() public {
        vm.prank(timelock);

        registry.registerAsset(usdc, AssetRegistry.AssetType.CollateralOnly, 6);

        vm.prank(timelock);

        registry.registerAsset(weth, AssetRegistry.AssetType.CollateralAndBorrowable, 18);

        assertEq(registry.assetList(0), usdc);
        assertEq(registry.assetList(1), weth);
    }

    function testRegisterIncrementsAssetCount() public {
        assertEq(registry.assetCount(), 0);

        vm.prank(timelock);

        registry.registerAsset(usdc, AssetRegistry.AssetType.CollateralOnly, 6);

        assertEq(registry.assetCount(), 1);
    }

    function testRegisterMarksAssetAsRegistered() public {
        _registerWeth();

        assertTrue(registry.isRegistered(weth));
    }

    function testTimelockCanRegister() public {
        vm.prank(timelock);

        registry.registerAsset(weth, AssetRegistry.AssetType.CollateralOnly, 18);

        (uint8 decimals, AssetRegistry.AssetType assetType, bool enabled) = registry.assets(weth);

        assertEq(decimals, 18);
        assertEq(uint256(assetType), uint256(AssetRegistry.AssetType.CollateralOnly));
        assertFalse(enabled);
    }

    function testRevertsIfNonTimelockCanRegister() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__NotTimelock.selector);
        vm.prank(attacker);

        registry.registerAsset(weth, AssetRegistry.AssetType.CollateralOnly, 18);
    }

    function testRegisterRevertsIfDecimalsTooLow() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__InvalidDecimals.selector);

        vm.prank(timelock);

        registry.registerAsset(usdc, AssetRegistry.AssetType.CollateralOnly, 1);
    }

    function testRegisterRevertsIfDecimalsTooHigh() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__InvalidDecimals.selector);

        vm.prank(timelock);

        registry.registerAsset(weth, AssetRegistry.AssetType.BorrowableOnly, 100);
    }

    function testAssetStartsDisabledAfterRegister() public {
        _registerWeth();

        (,, bool enabled) = registry.assets(weth);

        assertFalse(enabled);
    }
}
