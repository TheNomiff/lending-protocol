// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract PriceOracleEdgeCasesTest is OracleTestBase {
    function testVeryLargeETHAmountConversion() public view {
        uint256 ethAmount = 10_000 ether;

        uint256 actualUsd = oracle.getETHValueInUSD(ethAmount);

        uint256 expectedUsd = 20_000_000 ether;

        assertEq(actualUsd, expectedUsd);
    }

    function testVerySmallETHAmountConversion() public view {
        uint256 ethAmount = 0.001 ether;

        uint256 actualUsd = oracle.getETHValueInUSD(ethAmount);

        uint256 expectedUsd = 2 ether;

        assertEq(actualUsd, expectedUsd);
    }

    function testPriceUpdatesImmediatelyAffectConversions() public {
        uint256 ethAmount = 1 ether;

        uint256 oldValue = oracle.getETHValueInUSD(ethAmount);

        assertEq(oldValue, 2000 ether);

        _updatePrice(3000e8);

        uint256 newValue = oracle.getETHValueInUSD(ethAmount);

        assertEq(newValue, 3000 ether);
    }

    function testFeedReplacementImmediatelyChangesPrice() public {
        MockV3Aggregator newFeed = _deployMockFeed(5000e8);

        _replaceFeed(address(newFeed));

        uint256 price = oracle.getPrice();

        assertEq(price, 5000e8);
    }
}
