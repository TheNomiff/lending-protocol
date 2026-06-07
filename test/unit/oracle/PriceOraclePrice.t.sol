// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";
import {PriceOracle} from "../../../src/oracle/PriceOracle.sol";

contract PriceOraclePriceTest is OracleTestBase {
    function testGetPriceReturnsCorrectPrice() public view {
        uint256 actualPrice = oracle.getPrice();

        uint256 expectedPrice = 2000e8;

        assertEq(actualPrice, expectedPrice);
    }

    function testGetPriceRevertsIfPriceZero() public {
        int256 newPrice = 0;

        _updatePrice(newPrice);

        vm.expectRevert(PriceOracle.PriceOracle__InvalidPrice.selector);

        oracle.getPrice();
    }

    function testGetPriceRevertsIfPriceNegative() public {
        int256 newPrice = -2000e18;

        _updatePrice(newPrice);

        vm.expectRevert(PriceOracle.PriceOracle__InvalidPrice.selector);

        oracle.getPrice();
    }

    function testGetPriceRevertsIfStale() public {
        _warpPastStaleTime();

        vm.expectRevert(PriceOracle.PriceOracle__StalePrice.selector);

        oracle.getPrice();
    }
}
