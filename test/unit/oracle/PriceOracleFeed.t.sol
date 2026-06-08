// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {PriceOracle} from "../../../src/oracle/PriceOracle.sol";

contract PriceOracleFeedTest is OracleTestBase {
    function testOwnerCanUpdateFeed() public {
        MockV3Aggregator newFeed = _deployMockFeed(3000e8);

        _replaceFeed(address(newFeed));

        assertEq(address(oracle.priceFeed()), address(newFeed));
    }

    function testNonOwnerCannotUpdateFeed() public {
        MockV3Aggregator newFeed = _deployMockFeed(3000e8);

        vm.prank(ATTACKER);

        vm.expectRevert(PriceOracle.PriceOracle__NotOwner.selector);

        oracle.setPriceFeed(address(newFeed));
    }

    function testRevertsIfFeedZero() public {
        vm.expectRevert(PriceOracle.PriceOracle__InvalidFeed.selector);

        oracle.setPriceFeed(address(0));
    }

    function testUpdatedFeedReturnsNewPrice() public {
        MockV3Aggregator newFeed = _deployMockFeed(3000e8);

        oracle.setPriceFeed(address(newFeed));

        uint256 price = oracle.getPrice();

        assertEq(price, 3000e8);
    }
}
