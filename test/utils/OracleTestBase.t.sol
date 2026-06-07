// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PriceOracle} from "../../src/oracle/PriceOracle.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

abstract contract OracleTestBase is Test {
    PriceOracle internal oracle;
    MockV3Aggregator internal mockFeed;

    address internal owner = address(this);
    address internal constant USER = address(1);
    address internal constant ATTACKER = address(999);

    uint8 internal constant FEED_DECIMALS = 8;
    int256 internal constant ETH_PRICE = 2000e8;
    uint256 internal constant DEFAULT_STALE_TIME = 1 hours;

    function setUp() public virtual {
        mockFeed = new MockV3Aggregator(FEED_DECIMALS, ETH_PRICE);
        oracle = new PriceOracle(address(mockFeed));
    }

    //////////////////////////////
    ////// HELPER FUNCTIONS //////
    //////////////////////////////

    function _deployMockFeed(int256 initialPrice) internal returns (MockV3Aggregator) {
        return new MockV3Aggregator(FEED_DECIMALS, initialPrice);
    }

    function _deployOracle(address feed) internal returns (PriceOracle) {
        return new PriceOracle(feed);
    }

    function _updatePrice(int256 newPrice) internal {
        mockFeed.updateAnswer(newPrice);
    }

    function _setStaleTime(uint256 newTime) internal {
        oracle.setStaleTime(newTime);
    }

    function _pauseOracle() internal {
        oracle.pause();
    }

    function _unpauseOracle() internal {
        oracle.unpause();
    }

    function _transferOwnership(address newOwner) internal {
        oracle.transferOwnership(newOwner);
    }

    function _replaceFeed(address newFeed) internal {
        oracle.setPriceFeed(newFeed);
    }

    function _deployAndReplaceFeed(int256 price) internal returns (MockV3Aggregator newFeed) {
        newFeed = new MockV3Aggregator(FEED_DECIMALS, price);
        oracle.setPriceFeed(address(newFeed));
    }

    function _warpPastStaleTime() internal {
        vm.warp(block.timestamp + oracle.staleTime() + 1);
    }
}
