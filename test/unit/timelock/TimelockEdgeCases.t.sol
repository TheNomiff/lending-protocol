// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimelockTestBase} from "../../utils/TimelockTestBase.t.sol";
import {Timelock} from "../../../src/governance/Timelock.sol";
import {RiskEngine} from "../../../src/engines/RiskEngine.sol";

contract TimelockEdgeCasesTest is TimelockTestBase {
    RiskEngine riskEngine;

    function testMultipleTransactionsExecuteIndependently() public {
        uint256 txId1 = _queueSetValue(1);
        uint256 txId2 = _queueSetValue(2);
        uint256 txId3 = _queueSetValue(3);
        uint256 txId4 = _queueSetValue(4);

        _warpPastDelay();

        _executeTransaction(txId1);

        (address target,,, bool executed) = timelock.queuedTransactions(txId1);

        assertEq(mockTarget.value(), 1);
        assertEq(target, address(mockTarget));
        assertTrue(executed);

        _cancelTransaction(txId2);

        (address targetContract,,, bool isExecuted) = timelock.queuedTransactions(txId2);

        assertEq(mockTarget.value(), 1);
        assertEq(targetContract, address(0));
        assertFalse(isExecuted);

        _executeTransaction(txId3);

        (address targetAddress,,, bool isPass) = timelock.queuedTransactions(txId3);

        assertEq(mockTarget.value(), 3);
        assertEq(targetAddress, address(mockTarget));
        assertTrue(isPass);

        _cancelTransaction(txId4);

        (address aimAddress,,, bool isCancel) = timelock.queuedTransactions(txId4);

        assertEq(mockTarget.value(), 3);
        assertEq(aimAddress, address(0));
        assertFalse(isCancel);
    }

    function testExecuteOneSecondBeforeDelayReverts() public {
        uint256 txId = _queueSetValue(100);

        (,, uint256 executeAfter,) = timelock.queuedTransactions(txId);

        vm.warp(executeAfter - 1);

        vm.expectRevert(Timelock.Timelock__TooEarly.selector);

        _executeTransaction(txId);
    }

    function testQueueWithEmptyCalldata() public {
        bytes memory emptyData = "";
        uint256 expectedExecuteAfter = block.timestamp + timelock.DELAY();

        uint256 txId = timelock.queueTransaction(address(mockTarget), emptyData);

        (address target, bytes memory storedData, uint256 executeAfter, bool executed) =
            timelock.queuedTransactions(txId);

        assertEq(target, address(mockTarget));
        assertEq(storedData.length, 0);
        assertEq(executeAfter, expectedExecuteAfter);
        assertFalse(executed);
    }

    function testQueueSameTargetAndDataTwice() public {
        uint256 txId1 = _queueSetValue(100);
        uint256 txId2 = _queueSetValue(100);

        (address target1, bytes memory data1,,) = timelock.queuedTransactions(txId1);

        (address target2, bytes memory data2,,) = timelock.queuedTransactions(txId2);

        assertEq(txId1, 1);
        assertEq(txId2, 2);
        assertTrue(txId2 > txId1);
        assertEq(target1, address(mockTarget));
        assertEq(target2, address(mockTarget));
        assertEq(data1, data2);
    }

    function testRequeueAfterCancelGetsNewTxId() public {
        uint256 txId = _queueSetValue(1121);
        uint256 newTxId = _queueSetValue(1121);

        _cancelTransaction(txId);

        assertEq(txId, 1);
        assertEq(newTxId, 2);
        assertTrue(newTxId > txId);
    }

    function testExecuteCancelledTxSlotRevertsOrFails() public {
        uint256 txId = _queueSetValue(11);

        _cancelTransaction(txId);

        _warpPastDelay();

        vm.expectRevert(Timelock.Timelock__CancelledTransaction.selector);

        _executeTransaction(txId);
    }

    function testExecuteNonExistentTxIdInValidRange() public {
        _queueSetValue(11);

        vm.expectRevert(Timelock.Timelock__InvalidTxId.selector);

        _executeTransaction(2);
    }

    function testCancelAlreadyExecutedTransaction() public {
        uint256 txId = _queueSetValue(1143);

        _warpPastDelay();

        _executeTransaction(txId);

        vm.expectRevert(Timelock.Timelock__AlreadyExecuted.selector);

        _cancelTransaction(txId);
    }

    function testCancelSameTransactionTwice() public {
        uint256 txId = _queueSetValue(1111);

        _cancelTransaction(txId);

        vm.expectRevert(Timelock.Timelock__CancelledTransaction.selector);

        _cancelTransaction(txId);
    }

    function testQueueAfterMultipleCancelsPreservesTxIdMonotonicity() public {
        uint256 txId1 = _queueSetValue(1);
        uint256 txId2 = _queueSetValue(2);
        uint256 txId3 = _queueSetValue(3);

        _cancelTransaction(txId1);
        _cancelTransaction(txId2);

        uint256 txId4 = _queueSetValue(4);

        assertEq(txId1, 1);
        assertEq(txId2, 2);
        assertEq(txId3, 3);
        assertEq(txId4, 4);
        assertTrue(txId4 > txId1);
    }

    function testIntegrationExecuteRiskEngineOwnerFunction() public {
        // Verifies end-to-end flow: timelock queues and executes an owner-only call on a protocol contract (e.g. RiskEngine parameter update).
        riskEngine = new RiskEngine(1000 ether, 500 ether);

        riskEngine.transferOwnership(address(timelock));

        bytes memory data = abi.encodeCall(RiskEngine.updateLiquidationThreshold, (80));

        uint256 txId = timelock.queueTransaction(address(riskEngine), data);

        _warpPastDelay();

        _executeTransaction(txId);

        assertEq(riskEngine.owner(), address(timelock));
        assertEq(riskEngine.liquidationThreshold(), 80);
    }
}
