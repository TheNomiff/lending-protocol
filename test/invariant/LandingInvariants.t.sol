// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Landing} from "../../src/Landing.sol";
import {PriceOracle} from "../../src/oracle/PriceOracle.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {LandingHandler} from "./LandingHandler.t.sol";
import {RiskEngine} from "../../src/engines/RiskEngine.sol";
import {Timelock} from "../../src/governance/Timelock.sol";

contract LandingInvariants is StdInvariant, Test {
    Landing internal landing;
    LandingHandler internal handler;
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
        landing = new Landing(address(oracle), address(riskEngine));
        handler = new LandingHandler(landing);

        targetContract(address(handler));
    }

    function invariant_TotalLiquidityEqualsProtocolBalance() public view {
        assertEq(landing.totalLiquidity(), address(landing).balance);
    }
}
