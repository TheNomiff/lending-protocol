// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";

contract PriceOraclePriceTest is OracleTestBase {
    function testGetPriceReturnsCorrectPrice() public {}

    function testGetPriceRevertsIfPriceZero() public {}

    function testGetPriceRevertsIfPriceNegative() public {}

    function testGetPriceRevertsIfStale() public {}
}
