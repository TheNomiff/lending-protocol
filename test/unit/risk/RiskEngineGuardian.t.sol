// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskEngine} from "../../../src/engines/RiskEngine.sol";
import {RiskTestBase} from "../../utils/RiskTestBase.t.sol";

contract RiskEngineGuardianTest is RiskTestBase {
    function testOwnerCanTransferGuardian() public {
        address newGuardian = makeAddr("New Guardian");

        riskEngine.transferGuardian(newGuardian);

        assertEq(riskEngine.guardian(), newGuardian);
    }

    function testNonOwnerCannotTransferGuardian() public {
        address newGuardian = makeAddr("New Guardian");
        address attacker = makeAddr("Attacker");

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__NotOwner.selector);
        riskEngine.transferGuardian(newGuardian);
    }

    function testNewGuardianCanPauseAndOldGuardianCannot() public {
        address newGuardian = makeAddr("New Guardian");

        riskEngine.transferGuardian(newGuardian);

        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);
        riskEngine.pauseBorrowing();

        vm.prank(newGuardian);
        riskEngine.pauseBorrowing();
        assertTrue(riskEngine.borrowPaused());
    }

    function testTransferGuardianToZeroAddressReverts() public {
        vm.expectRevert(RiskEngine.RiskEngine__InvalidGuardian.selector);

        riskEngine.transferGuardian(address(0));
    }
}
