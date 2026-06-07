// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";
import {PriceOracle} from "../../../src/oracle/PriceOracle.sol";

contract PriceOracleConstructorTest is OracleTestBase {
    function testConstructorSetsOwner() public view {
        assertEq(oracle.owner(), address(this));
    }

    function testConstructorSetsFeed() public view {
        assertEq(address(oracle.priceFeed()), address(mockFeed));
    }

    function testConstructorRevertsIfFeedZero() public {
        vm.expectRevert(PriceOracle.PriceOracle__InvalidFeed.selector);

        new PriceOracle(address(0));
    }
}
