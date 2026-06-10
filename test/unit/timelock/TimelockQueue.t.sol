// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimelockTestBase} from "../../utils/TimelockTestBase.t.sol";
import {MockTarget} from "../../utils/TimelockTestBase.t.sol";
import {Timelock} from "../../../src/governance/Timelock.sol";

contract TimelockQueueTest is TimelockTestBase {
    function testOwnerCanQueueTransaction() public {
        uint256 txId = _queueSetValue(100);

        assertEq(txId, 1);
    }

    function testQueueIncrementsTxCount() public {
        assertEq(timelock.txCount(), 0);

        _queueSetValue(100);

        assertEq(timelock.txCount(), 1);
    }

    function testQueueReturnsSequentialTxIds() public {
        uint256 txId1 = _queueSetValue(100);
        uint256 txId2 = _queueSetValue(20);
        uint256 txId3 = _queueSetValue(200);

        assertEq(txId1, 1);
        assertEq(txId2, 2);
        assertEq(txId3, 3);
    }

    function testQueueStoresCorrectTarget() public {
        uint256 txId = _queueSetValue(300);

        (address target,,,) = timelock.queuedTransactions(txId);

        assertEq(target, address(mockTarget));
    }

    function testQueueStoresCorrectData() public {
        bytes memory expectedData = abi.encodeCall(MockTarget.setValue, (50));

        uint256 txId = _queueSetValue(50);

        (, bytes memory storedData,,) = timelock.queuedTransactions(txId);

        assertEq(storedData, expectedData);
    }

    function testQueueSetsExecuteAfterToDelayFromNow() public {
        uint256 expectedTime = block.timestamp + timelock.DELAY();

        uint256 txId = _queueSetValue(10);

        (,, uint256 executeAfter,) = timelock.queuedTransactions(txId);

        assertEq(expectedTime, executeAfter);
    }

    function testQueueSetsExecutedToFalse() public {
        uint256 txId = _queueSetValue(500);

        (,,, bool executed) = timelock.queuedTransactions(txId);

        assertFalse(executed);
    }

    function testQueueEmitsTransactionQueued() public {
        uint256 expectedExecuteAfter = block.timestamp + timelock.DELAY();
        bytes memory data = abi.encodeCall(MockTarget.setValue, (1100));

        vm.expectEmit();

        emit Timelock.TransactionQueued(1, address(mockTarget), data, expectedExecuteAfter);

        timelock.queueTransaction(address(mockTarget), data);
    }

    function testQueueRevertsIfTargetZero() public {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (100));

        vm.expectRevert(Timelock.Timelock__InvalidTarget.selector);
        timelock.queueTransaction(address(0), data);
    }

    function testNonOwnerCannotQueueTransaction() public {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (100));

        vm.prank(NON_OWNER);
        vm.expectRevert(Timelock.Timelock__NotOwner.selector);

        timelock.queueTransaction(address(mockTarget), data);
    }
}
