// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RegistryTestBase} from "../../utils/RegistryTestBase.t.sol";
import {AssetRegistry} from "../../../src/registry/AssetRegistry.sol";

contract AssetRegistryTest is RegistryTestBase {
    function testUpdateAsset() public {
        _registerWeth();

        _updateAsset(weth, AssetRegistry.AssetType.CollateralAndBorrowable);

        (, AssetRegistry.AssetType assetType,) = registry.assets(weth);

        assertEq(uint256(assetType), uint256(AssetRegistry.AssetType.CollateralAndBorrowable));
    }

    function testUpdateRevertsIfAssetNotRegistered() public {
        vm.expectRevert(AssetRegistry.AssetRegistry__AssetNotRegistered.selector);

        _updateAsset(weth, AssetRegistry.AssetType.CollateralOnly);
    }

    function testUpdateRevertsIfInvalidAssetType() public {
        vm.prank(timelock);

        registry.registerAsset(usdc, AssetRegistry.AssetType.CollateralOnly, 6);

        vm.expectRevert(AssetRegistry.AssetRegistry__InvalidAssetType.selector);

        _updateAsset(usdc, AssetRegistry.AssetType.None);
    }

    function testUpdateRevertsIfValueUnchanged() public {
        _registerWeth();

        vm.expectRevert(AssetRegistry.AssetRegistry__ValueUnchanged.selector);

        _updateAsset(weth, AssetRegistry.AssetType.CollateralOnly);
    }

    function testTimelockCanUpdate() public {
        _registerWeth();

        vm.prank(timelock);

        registry.updateAsset(weth, AssetRegistry.AssetType.BorrowableOnly);

        (, AssetRegistry.AssetType assetType,) = registry.assets(weth);

        assertEq(uint256(assetType), uint256(AssetRegistry.AssetType.BorrowableOnly));
    }

    function testRevertsIfNonTimelockCannotUpdate() public {
        _registerWeth();

        vm.prank(attacker);

        vm.expectRevert(AssetRegistry.AssetRegistry__NotTimelock.selector);

        registry.updateAsset(weth, AssetRegistry.AssetType.BorrowableOnly);
    }

    function testUpdateEmitsEvent() public {
        _registerWeth();

        (, AssetRegistry.AssetType oldType,) = registry.assets(weth);

        vm.expectEmit(true, true, true, true);

        emit AssetRegistry.AssetUpdated(weth, oldType, AssetRegistry.AssetType.CollateralAndBorrowable);

        _updateAsset(weth, AssetRegistry.AssetType.CollateralAndBorrowable);
    }
}
