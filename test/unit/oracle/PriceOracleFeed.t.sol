// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";

contract PriceOracleFeedTest is OracleTestBase {
    function testOwnerCanUpdateFeed() public {}

    function testNonOwnerCannotUpdateFeed() public {}

    function testRevertsIfFeedZero() public {}
}
