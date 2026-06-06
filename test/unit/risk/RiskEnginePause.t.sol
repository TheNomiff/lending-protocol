// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskEngine} from "../../../src/engines/RiskEngine.sol";
import {RiskTestBase} from "../../utils/RiskTestBase.t.sol";

contract RiskEnginePauseTest is RiskTestBase {
    function testGuardianCanPauseBorrow() public {
        bool beforeState = riskEngine.borrowPaused();

        riskEngine.pauseBorrowing();

        bool afterState = riskEngine.borrowPaused();

        assertFalse(beforeState);
        assertTrue(afterState);
    }

    function testGuardianCanUnpauseBorrow() public {
        riskEngine.pauseBorrowing();
        bool beforeState = riskEngine.borrowPaused();

        riskEngine.unpauseBorrowing();
        bool afterState = riskEngine.borrowPaused();

        assertTrue(beforeState);
        assertFalse(afterState);
    }

    function testNonGuardianCannotPauseBorrow() public {
        address attacker = makeAddr("Attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);

        riskEngine.pauseBorrowing();
    }

    function testNonGuardianCannotUnpauseBorrow() public {
        riskEngine.pauseBorrowing();

        address attacker = makeAddr("Attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);

        riskEngine.unpauseBorrowing();
    }

    function testPauseBorrowRevertsIfAlreadyPaused() public {
        riskEngine.pauseBorrowing();

        vm.expectRevert(RiskEngine.RiskEngine__AlreadyPaused.selector);

        riskEngine.pauseBorrowing();
    }

    function testUnpauseBorrowRevertsIfAlreadyUnpaused() public {
        vm.expectRevert(RiskEngine.RiskEngine__AlreadyUnpaused.selector);

        riskEngine.unpauseBorrowing();
    }

    function testGuardianCanPauseDeposit() public {
        bool beforeState = riskEngine.depositPaused();

        riskEngine.pauseDepositing();

        bool afterState = riskEngine.depositPaused();

        assertFalse(beforeState);
        assertTrue(afterState);
    }

    function testGuardianCanUnpauseDeposit() public {
        riskEngine.pauseDepositing();
        bool beforeState = riskEngine.depositPaused();

        riskEngine.unpauseDepositing();
        bool afterState = riskEngine.depositPaused();

        assertTrue(beforeState);
        assertFalse(afterState);
    }

    function testNonGuardianCannotPauseDeposit() public {
        address attacker = makeAddr("Attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);

        riskEngine.pauseDepositing();
    }

    function testNonGuardianCannotUnpauseDeposit() public {
        riskEngine.pauseDepositing();

        address attacker = makeAddr("Attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);

        riskEngine.unpauseDepositing();
    }

    function testPauseDepositRevertsIfAlreadyPaused() public {
        riskEngine.pauseDepositing();

        vm.expectRevert(RiskEngine.RiskEngine__AlreadyPaused.selector);

        riskEngine.pauseDepositing();
    }

    function testUnpauseDepositRevertsIfAlreadyUnpaused() public {
        vm.expectRevert(RiskEngine.RiskEngine__AlreadyUnpaused.selector);

        riskEngine.unpauseDepositing();
    }

    function testGuardianCanPauseLiquidation() public {
        bool beforeState = riskEngine.liquidationPaused();

        riskEngine.pauseLiquidation();

        bool afterState = riskEngine.liquidationPaused();

        assertFalse(beforeState);
        assertTrue(afterState);
    }

    function testGuardianCanUnpauseLiquidation() public {
        riskEngine.pauseLiquidation();
        bool beforeState = riskEngine.liquidationPaused();

        riskEngine.unpauseLiquidation();
        bool afterState = riskEngine.liquidationPaused();

        assertTrue(beforeState);
        assertFalse(afterState);
    }

    function testNonGuardianCannotPauseLiquidation() public {
        address attacker = makeAddr("Attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);

        riskEngine.pauseLiquidation();
    }

    function testNonGuardianCannotUnpauseLiquidation() public {
        riskEngine.pauseLiquidation();

        address attacker = makeAddr("Attacker");

        vm.prank(attacker);

        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);
        riskEngine.unpauseLiquidation();
    }

    function testPauseLiquidationRevertsIfAlreadyPaused() public {
        riskEngine.pauseLiquidation();

        vm.expectRevert(RiskEngine.RiskEngine__AlreadyPaused.selector);

        riskEngine.pauseLiquidation();
    }

    function testUnpauseLiquidationRevertsIfAlreadyUnpaused() public {
        vm.expectRevert(RiskEngine.RiskEngine__AlreadyUnpaused.selector);

        riskEngine.unpauseLiquidation();
    }
}
