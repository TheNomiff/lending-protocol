// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimelockTestBase} from "../../utils/TimelockTestBase.t.sol";
import {MockTarget} from "../../utils/TimelockTestBase.t.sol";
import {Timelock} from "../../../src/governance/Timelock.sol";

contract TimelockCancelTest is TimelockTestBase {
    function testOwnerCanCancelQueuedTransaction() public {
        uint256 txId = _queueSetValue(1234);

        _cancelTransaction(txId);

        (address target,, uint256 executeAfter, bool executed) = timelock.queuedTransactions(txId);

        assertEq(target, address(0));
        assertEq(executeAfter, 0);
        assertFalse(executed);
    }

    function testCancelDeletesQueuedTransaction() public {
        uint256 txId = _queueSetValue(1234);

        _cancelTransaction(txId);

        uint256 isCount = timelock.txCount();

        (address target,, uint256 executeAfter, bool executed) = timelock.queuedTransactions(txId);

        assertEq(isCount, 1);
        assertEq(target, address(0));
        assertEq(executeAfter, 0);
        assertFalse(executed);
    }

    function testCancelEmitsTransactionCancelled() public {
        uint256 txId = _queueSetValue(134);
        uint256 id = timelock.txCount();

        vm.expectEmit();

        emit Timelock.TransactionCancelled(id);

        _cancelTransaction(txId);
    }

    function testCancelRevertsIfInvalidTxIdZero() public {
        vm.expectRevert(Timelock.Timelock__InvalidTxId.selector);

        _cancelTransaction(0);
    }

    function testCancelRevertsIfInvalidTxIdExceedsTxCount() public {
        _queueSetValue(145);

        vm.expectRevert(Timelock.Timelock__InvalidTxId.selector);

        _cancelTransaction(2);
    }

    function testNonOwnerCannotCancelTransaction() public {
        uint256 txId = _queueSetValue(185);

        vm.prank(NON_OWNER);
        vm.expectRevert(Timelock.Timelock__NotOwner.selector);

        _cancelTransaction(txId);
    }

    function testOwnerCanCancelBeforeDelayExpires() public {
        uint256 txId = _queueSetValue(167);

        _cancelTransaction(txId);

        (address target,, uint256 executeAfter, bool executed) = timelock.queuedTransactions(txId);

        assertEq(target, address(0));
        assertEq(executeAfter, 0);
        assertFalse(executed);
    }

    function testOwnerCanCancelAfterDelayExpires() public {
        uint256 txId = _queueSetValue(187);

        _warpPastDelay();

        _cancelTransaction(txId);

        (address target,, uint256 executeAfter, bool executed) = timelock.queuedTransactions(txId);

        assertEq(target, address(0));
        assertEq(executeAfter, 0);
        assertFalse(executed);
    }

    function testTxCountNotDecrementedOnCancel() public {
        uint256 txId = _queueSetValue(100);

        assertEq(timelock.txCount(), 1);

        _cancelTransaction(txId);

        uint256 newTxId = _queueSetValue(999);

        assertEq(newTxId, 2);
    }

    function testCancelledTransactionCanStillBeExecuted() public {
        uint256 txId = _queueSetValue(500);

        _cancelTransaction(txId);

        _warpPastDelay();

        vm.expectRevert(Timelock.Timelock__CancelledTransaction.selector);

        _executeTransaction(txId);
    }
}
