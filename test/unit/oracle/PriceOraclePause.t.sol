// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";

contract PriceOraclePauseTest is OracleTestBase {
    function testOwnerCanPause() public {}

    function testOwnerCanUnpause() public {}

    function testNonOwnerCannotPause() public {}

    function testNonOwnerCannotUnpause() public {}

    function testGetPriceRevertsWhenPaused() public {}
}
