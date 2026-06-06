// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";

contract PriceOracleOwnershipTest is OracleTestBase {
    function testTransferOwnership() public {}

    function testTransferOwnershipZeroAddressReverts() public {}

    function testNonOwnerCannotTransferOwnership() public {}

    function testNewOwnerCanCallOwnerFunctions() public {}

    function testOldOwnerCannotCallOwnerFunctions() public {}
}
