// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskEngine} from "../../../src/engines/RiskEngine.sol";
import {RiskTestBase} from "../../utils/RiskTestBase.t.sol";

contract RiskEngineConstructorTest is RiskTestBase {
    function testConstructorSetsOwner() public view {
        assertEq(riskEngine.owner(), address(this));
    }

    function testConstructorSetsGuardian() public view {
        assertEq(riskEngine.guardian(), address(this));
    }

    function testConstructorSetsCaps() public view {
        assertEq(riskEngine.supplyCap(), SUPPLY_CAP);
        assertEq(riskEngine.borrowCap(), BORROW_CAP);
    }

    function testConstructorRevertsIfSupplyCapZero() public {
        vm.expectRevert(RiskEngine.RiskEngine__InvalidCaps.selector);

        new RiskEngine(0, BORROW_CAP);
    }

    function testConstructorRevertsIfBorrowCapZero() public {
        vm.expectRevert(RiskEngine.RiskEngine__InvalidCaps.selector);

        new RiskEngine(SUPPLY_CAP, 0);
    }

    function testConstructorRevertsIfBorrowCapExceedsSupplyCap() public {
        vm.expectRevert(RiskEngine.RiskEngine__InvalidCaps.selector);

        new RiskEngine(100 ether, 200 ether);
    }
}
