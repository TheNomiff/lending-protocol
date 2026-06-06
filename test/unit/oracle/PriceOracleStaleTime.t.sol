// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";

contract PriceOracleStaleTimeTest is OracleTestBase {
    function testOwnerCanUpdateStaleTime() public {}

    function testNonOwnerCannotUpdateStaleTime() public {}
}
