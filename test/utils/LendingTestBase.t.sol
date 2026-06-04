// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Lending} from "../../src/Lending.sol";
import {PriceOracle} from "../../src/oracle/PriceOracle.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {RiskEngine} from "../../src/engines/RiskEngine.sol";
import {Timelock} from "../../src/governance/Timelock.sol";

abstract contract LendingTestBase is Test {
    Lending internal lending;
    PriceOracle internal oracle;
    MockV3Aggregator internal mockFeed;
    RiskEngine internal riskEngine;
    Timelock internal timelock;

    address internal constant USER = address(1);
    address internal constant USER_A = address(2);
    address internal constant USER_B = address(3);

    uint8 internal constant FEED_DECIMALS = 8;
    int256 internal constant ETH_PRICE = 2000e8;

    function setUp() public virtual {
        mockFeed = new MockV3Aggregator(FEED_DECIMALS, ETH_PRICE);
        oracle = new PriceOracle(address(mockFeed));
        oracle.setStaleTime(500 days);
        riskEngine = new RiskEngine(1000 ether, 500 ether);
        timelock = new Timelock();
        oracle.transferOwnership(address(timelock));
        riskEngine.transferOwnership(address(timelock));

        lending = new Lending(address(oracle), address(riskEngine));

        _fundUser(USER, 100 ether);
        _fundUser(USER_A, 100 ether);
        _fundUser(USER_B, 100 ether);
    }

    function _fundUser(address user, uint256 amount) internal {
        vm.deal(user, amount);
    }

    function _depositAs(address user, uint256 amount) internal {
        vm.prank(user);
        lending.deposit{value: amount}();
    }

    function _borrowAs(address user, uint256 amount) internal {
        vm.prank(user);
        lending.borrow(amount);
    }

    function _withdrawAs(address user, uint256 amount) internal {
        vm.prank(user);
        lending.withdraw(amount);
    }

    function _repayAs(address user, uint256 amount) internal {
        vm.prank(user);
        lending.repay{value: amount}();
    }

    function _openPosition(address user, uint256 depositAmount, uint256 borrowAmount) internal {
        _depositAs(user, depositAmount);
        _borrowAs(user, borrowAmount);
    }

    function _userPosition(address user)
        internal
        view
        returns (uint256 deposited, uint256 borrowed, uint256 lastBorrowTimestamp)
    {
        return lending.users(user);
    }
}
