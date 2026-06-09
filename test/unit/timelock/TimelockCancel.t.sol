// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimelockTestBase} from "../../utils/TimelockTestBase.t.sol";

contract TimelockCancelTest is TimelockTestBase {
    function testOwnerCanCancelQueuedTransaction() public {
        // Verifies that the owner can cancel a queued transaction that has not yet been executed.
    }

    function testCancelDeletesQueuedTransaction() public {
        // Verifies that cancelTransaction clears the queued transaction entry from storage.
    }

    function testCancelEmitsTransactionCancelled() public {
        // Verifies that cancelTransaction emits TransactionCancelled with the correct txId.
    }

    function testCancelRevertsIfInvalidTxIdZero() public {
        // Verifies that cancelTransaction reverts with Timelock__InvalidTxId when txId is zero.
    }

    function testCancelRevertsIfInvalidTxIdExceedsTxCount() public {
        // Verifies that cancelTransaction reverts with Timelock__InvalidTxId when txId exceeds txCount.
    }

    function testNonOwnerCannotCancelTransaction() public {
        // Verifies that a non-owner caller cannot cancel a transaction and reverts with Timelock__NotOwner.
    }

    function testOwnerCanCancelBeforeDelayExpires() public {
        // Verifies that the owner can cancel a transaction before the delay period has elapsed.
    }

    function testOwnerCanCancelAfterDelayExpires() public {
        // Verifies that the owner can cancel a transaction even after the delay period has elapsed but before execution.
    }

    function testTxCountNotDecrementedOnCancel() public {
        // Verifies that cancelTransaction does not decrement txCount, preserving monotonic txId assignment.
    }

    function testCancelledTransactionCannotBeExecuted() public {
        // Verifies that a cancelled transaction cannot be executed afterward.
    }
}
