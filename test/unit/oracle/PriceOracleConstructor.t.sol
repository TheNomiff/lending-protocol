// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";

contract PriceOracleConstructorTest is OracleTestBase {
    function testConstructorSetsOwner() public {}

    function testConstructorSetsFeed() public {}

    function testConstructorRevertsIfFeedZero() public {}
}
