// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";

contract PriceOracleEdgeCasesTest is OracleTestBase {
    function testVeryLargeETHAmountConversion() public {}

    function testVerySmallETHAmountConversion() public {}

    function testPriceUpdatesImmediatelyAffectConversions() public {}
}
