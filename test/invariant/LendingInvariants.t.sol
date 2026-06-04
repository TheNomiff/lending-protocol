// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Lending} from "../../src/Lending.sol";
import {PriceOracle} from "../../src/oracle/PriceOracle.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {LendingHandler} from "./LendingHandler.t.sol";
import {RiskEngine} from "../../src/engines/RiskEngine.sol";
import {Timelock} from "../../src/governance/Timelock.sol";

contract LendingInvariants is StdInvariant, Test {
    Lending internal lending;
    LendingHandler internal handler;
    RiskEngine internal riskEngine;
    Timelock internal timelock;

    function setUp() public {
        MockV3Aggregator feed = new MockV3Aggregator(8, 2000e8);
        PriceOracle oracle = new PriceOracle(address(feed));
        oracle.setStaleTime(500 days);
        riskEngine = new RiskEngine(1000 ether, 500 ether);
        timelock = new Timelock();
        oracle.transferOwnership(address(timelock));
        riskEngine.transferOwnership(address(timelock));
        lending = new Lending(address(oracle), address(riskEngine));
        handler = new LendingHandler(lending);

        targetContract(address(handler));
    }

    function invariant_TotalLiquidityEqualsProtocolBalance() public view {
        assertEq(lending.totalLiquidity(), address(lending).balance);
    }
}
