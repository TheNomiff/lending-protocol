// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimelockTestBase} from "../../utils/TimelockTestBase.t.sol";
import {Timelock} from "../../../src/governance/Timelock.sol";

contract TimelockOwnershipTest is TimelockTestBase {
    function testOwnerCanQueueTransaction() public {
        uint256 txId = _queueSetValue(232);

        assertEq(txId, 1);
    }

    function testOwnerCanExecuteTransaction() public {
        uint256 txId = _queueSetValue(232);

        _warpPastDelay();

        _executeTransaction(txId);

        (address target,,, bool executed) = timelock.queuedTransactions(txId);

        assertEq(target, address(mockTarget));
        assertTrue(executed);
        assertEq(mockTarget.value(), 232);
    }

    function testOwnerCanCancelTransaction() public {
        uint256 txId = _queueSetValue(432);

        _cancelTransaction(txId);

        (address target,,, bool executed) = timelock.queuedTransactions(txId);

        assertEq(target, address(0));
        assertFalse(executed);
    }

    function testNonOwnerCannotQueueTransaction() public {
        vm.prank(NON_OWNER);
        vm.expectRevert(Timelock.Timelock__NotOwner.selector);

        _queueSetValue(312);
    }

    function testNonOwnerCannotExecuteTransaction() public {
        uint256 txId = _queueSetValue(3112);

        _warpPastDelay();

        vm.prank(NON_OWNER);
        vm.expectRevert(Timelock.Timelock__NotOwner.selector);

        _executeTransaction(txId);
    }

    function testNonOwnerCannotCancelTransaction() public {
        uint256 txId = _queueSetValue(332);

        vm.prank(NON_OWNER);
        vm.expectRevert(Timelock.Timelock__NotOwner.selector);

        _cancelTransaction(txId);
    }
}
