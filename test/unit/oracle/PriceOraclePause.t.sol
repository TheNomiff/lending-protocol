// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";
import {PriceOracle} from "../../../src/oracle/PriceOracle.sol";

contract PriceOraclePauseTest is OracleTestBase {
    function testOwnerCanPause() public {
        address owner = address(this);

        _pauseOracle();

        assertEq(owner, oracle.owner());
        assertTrue(oracle.paused());
    }

    function testOwnerCanUnpause() public {
        address owner = address(this);

        _pauseOracle();

        assertEq(owner, oracle.owner());
        assertTrue(oracle.paused());

        _unpauseOracle();

        assertFalse(oracle.paused());
    }

    function testNonOwnerCannotPause() public {
        vm.prank(ATTACKER);
        vm.expectRevert(PriceOracle.PriceOracle__NotOwner.selector);

        oracle.unpause();
    }

    function testNonOwnerCannotUnpause() public {
        _pauseOracle();

        vm.prank(ATTACKER);
        vm.expectRevert(PriceOracle.PriceOracle__NotOwner.selector);

        oracle.unpause();
    }

    function testGetPriceRevertsWhenPaused() public {
        _pauseOracle();

        vm.expectRevert(PriceOracle.PriceOracle__Paused.selector);
        oracle.getPrice();
    }
}
