// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskEngine} from "../../src/engines/RiskEngine.sol";
import {RiskTestBase} from "../utils/RiskTestBase.t.sol";

contract RiskEngineTest is RiskTestBase {
    //////////////////////////////////
    ////// CONSTRUCTOR TESTS ////////
    //////////////////////////////////

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

    //////////////////////////////////
    ////// HEALTH FACTOR TESTS //////
    //////////////////////////////////

    function testHealthFactorReturnsMaxWhenDebtZero() public {}

    function testHealthFactorCalculation() public {}

    //////////////////////////////////
    ////// BORROW TESTS /////////////
    //////////////////////////////////

    function testCanBorrowReturnsTrue() public {}

    function testCanBorrowReturnsFalse() public {}

    //////////////////////////////////
    ////// WITHDRAW TESTS ///////////
    //////////////////////////////////

    function testCanWithdrawReturnsTrue() public {}

    function testCanWithdrawReturnsFalse() public {}

    //////////////////////////////////
    ////// LIQUIDATION TESTS ////////
    //////////////////////////////////

    function testIsLiquidatableReturnsTrue() public {}

    function testIsLiquidatableReturnsFalse() public {}

    function testCalculateMaxLiquidation() public {}

    function testCalculateSeizedCollateral() public {}
}
