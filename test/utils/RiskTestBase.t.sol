// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RiskEngine} from "../../src/engines/RiskEngine.sol";

abstract contract RiskTestBase is Test {
    RiskEngine internal riskEngine;

    address internal owner = address(this);
    address internal constant GUARDIAN = address(100);
    address internal constant USER = address(1);

    uint256 internal constant SUPPLY_CAP = 1000 ether;
    uint256 internal constant BORROW_CAP = 500 ether;

    function setUp() public virtual {
        riskEngine = new RiskEngine(SUPPLY_CAP, BORROW_CAP);
    }
}
