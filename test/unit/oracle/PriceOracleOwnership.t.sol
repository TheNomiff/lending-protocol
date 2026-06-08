// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";
import {PriceOracle} from "../../../src/oracle/PriceOracle.sol";

contract PriceOracleOwnershipTest is OracleTestBase {
    function testTransferOwnership() public {
        address newOwner = makeAddr("New Onwer");

        assertEq(oracle.owner(), address(this));

        _transferOwnership(newOwner);

        assertEq(oracle.owner(), newOwner);
    }

    function testTransferOwnershipZeroAddressReverts() public {
        address newOwner = address(0);

        vm.expectRevert(PriceOracle.PriceOracle__InvalidOwner.selector);

        _transferOwnership(newOwner);
    }

    function testNonOwnerCannotTransferOwnership() public {
        address newOwner = makeAddr("New Onwer");

        vm.prank(ATTACKER);
        vm.expectRevert(PriceOracle.PriceOracle__NotOwner.selector);

        oracle.transferOwnership(newOwner);
    }

    function testNewOwnerCanCallOwnerFunctions() public {
        uint256 newStaleTime = 2 hours;
        address newOwner = makeAddr("New Onwer");

        _transferOwnership(newOwner);

        vm.prank(newOwner);

        oracle.setStaleTime(newStaleTime);

        assertEq(oracle.staleTime(), newStaleTime);
    }

    function testOldOwnerCannotCallOwnerFunctions() public {
        uint256 newStaleTime = 2 hours;
        address newOwner = makeAddr("New Onwer");
        address oldOwner = address(this);

        _transferOwnership(newOwner);

        assertEq(oracle.owner(), newOwner);

        vm.prank(oldOwner);
        vm.expectRevert(PriceOracle.PriceOracle__NotOwner.selector);

        oracle.setStaleTime(newStaleTime);
    }
}
