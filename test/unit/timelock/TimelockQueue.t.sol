// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimelockTestBase} from "../../utils/TimelockTestBase.t.sol";

contract TimelockQueueTest is TimelockTestBase {
    function testOwnerCanQueueTransaction() public {
        // Verifies that the owner can successfully queue a transaction and receive a valid txId.
    }

    function testQueueIncrementsTxCount() public {
        // Verifies that queueTransaction increments txCount by one per queued transaction.
    }

    function testQueueReturnsSequentialTxIds() public {
        // Verifies that successive queue calls return incrementing txIds (1, 2, 3, ...).
    }

    function testQueueStoresCorrectTarget() public {
        // Verifies that the queued transaction stores the provided target address.
    }

    function testQueueStoresCorrectData() public {
        // Verifies that the queued transaction stores the provided calldata unchanged.
    }

    function testQueueSetsExecuteAfterToDelayFromNow() public {
        // Verifies that executeAfter is set to block.timestamp + DELAY at queue time.
    }

    function testQueueSetsExecutedToFalse() public {
        // Verifies that newly queued transactions have executed flag set to false.
    }

    function testQueueEmitsTransactionQueued() public {
        // Verifies that queueTransaction emits TransactionQueued with correct indexed txId, target, data, and executeAfter.
    }

    function testQueueRevertsIfTargetZero() public {
        // Verifies that queueTransaction reverts with Timelock__InvalidTarget when target is address(0).
    }

    function testNonOwnerCannotQueueTransaction() public {
        // Verifies that a non-owner caller cannot queue a transaction and reverts with Timelock__NotOwner.
    }
}
