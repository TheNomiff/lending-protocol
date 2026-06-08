// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";
import {PriceOracle} from "../../../src/oracle/PriceOracle.sol";

contract PriceOracleStaleTimeTest is OracleTestBase {
    function testOwnerCanUpdateStaleTime() public {
        uint256 newTime = 2 hours;

        _setStaleTime(newTime);

        assertEq(oracle.staleTime(), newTime);
    }

    function testNonOwnerCannotUpdateStaleTime() public {
        uint256 newTime = 2 hours;

        vm.prank(ATTACKER);
        vm.expectRevert(PriceOracle.PriceOracle__NotOwner.selector);

        oracle.setStaleTime(newTime);
    }

    function testStaleTimeActuallyChangesValidationWindow() public {
        uint256 newTime = 2 hours;

        oracle.setStaleTime(newTime);

        vm.warp(block.timestamp + 90 minutes);

        uint256 price = oracle.getPrice();

        assertEq(price, ETH_PRICE);
    }

    function testPriceRevertsAfterUpdatedStaleWindow() public {
        oracle.setStaleTime(2 hours);

        vm.warp(block.timestamp + 2 hours + 1);

        vm.expectRevert(PriceOracle.PriceOracle__StalePrice.selector);

        oracle.getPrice();
    }
}
