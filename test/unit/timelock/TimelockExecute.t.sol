// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimelockTestBase} from "../../utils/TimelockTestBase.t.sol";
import {MockTarget} from "../../utils/TimelockTestBase.t.sol";
import {Timelock} from "../../../src/governance/Timelock.sol";
import {console2} from "forge-std/console2.sol";

contract TimelockExecuteTest is TimelockTestBase {
    function testOwnerCanExecuteAfterDelay() public {
        uint256 txId = _queueSetValue(100);

        _warpPastDelay();
        _executeTransaction(txId);

        (address target,,, bool executed) = timelock.queuedTransactions(txId);

        assertTrue(executed);
        assertEq(target, address(mockTarget));
        assertEq(mockTarget.value(), 100);
    }

    function testExecuteCallsTargetWithCorrectData() public {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (1000));

        uint256 txId = _queueSetValue(1000);

        _warpPastDelay();
        _executeTransaction(txId);

        (address target, bytes memory storedData,, bool executed) = timelock.queuedTransactions(txId);

        assertTrue(executed);
        assertEq(storedData, data);
        assertEq(target, address(mockTarget));
        assertEq(mockTarget.value(), 1000);
    }

    function testExecuteMarksTransactionAsExecuted() public {
        uint256 txId = _queueSetValue(100);

        _warpPastDelay();
        _executeTransaction(txId);

        (,,, bool executed) = timelock.queuedTransactions(txId);

        assertTrue(executed);
    }

    function testExecuteEmitsTransactionExecuted() public {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (2017));
        uint256 txId = _queueSetValue(2017);
        uint256 expectedTxId = timelock.txCount();

        _warpPastDelay();

        vm.expectEmit();

        emit Timelock.TransactionExecuted(expectedTxId, address(mockTarget), data);

        timelock.executeTransaction(txId);
    }

    function testExecuteRevertsIfTooEarly() public {
        uint256 txId = _queueSetValue(2007);

        vm.expectRevert(Timelock.Timelock__TooEarly.selector);
        _executeTransaction(txId);
    }

    function testExecuteSucceedsAtExactExecuteAfterBoundary() public {
        uint256 txId = _queueSetValue(2007);

        (,, uint256 executeAfter,) = timelock.queuedTransactions(txId);

        vm.warp(executeAfter);

        _executeTransaction(txId);

        assertEq(mockTarget.value(), 2007);
    }

    function testExecuteRevertsIfAlreadyExecuted() public {
        uint256 txId = _queueSetValue(2006);

        _warpPastDelay();

        _executeTransaction(txId);

        vm.expectRevert(Timelock.Timelock__AlreadyExecuted.selector);

        _executeTransaction(txId);
    }

    function testExecuteRevertsIfInvalidTxIdZero() public {
        vm.expectRevert(Timelock.Timelock__InvalidTxId.selector);

        _executeTransaction(0);
    }

    function testExecuteRevertsIfInvalidTxIdExceedsTxCount() public {
        _queueSetValue(207);

        vm.expectRevert(Timelock.Timelock__InvalidTxId.selector);
        _executeTransaction(2);
    }

    function testExecuteRevertsIfTargetCallFails() public {
        mockTarget.setShouldRevert(true);

        uint256 txId = _queueSetValue(300);

        _warpPastDelay();

        vm.expectRevert(Timelock.Timelock__ExecutionFailed.selector);

        _executeTransaction(txId);
    }

    function testNonOwnerCannotExecuteTransaction() public {
        uint256 txId = _queueSetValue(20);

        _warpPastDelay();

        vm.prank(NON_OWNER);
        vm.expectRevert(Timelock.Timelock__NotOwner.selector);

        timelock.executeTransaction(txId);
    }
}
