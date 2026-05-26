// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    //////////////////
    //// ERRORS ////
    //////////////////

    error Timelock__NotOwner();
    error Timelock__TooEarly();
    error Timelock__AlreadyExecuted();
    error Timelock__InvalidTxId();
    error Timelock__InvalidTarget();
    error Timelock__ExecutionFailed();

    //////////////////
    //// EVENTS ////
    //////////////////

    event TransactionQueued(uint256 indexed txId, address target, bytes data, uint256 executeAfter);
    event TransactionExecuted(uint256 indexed txId, address target, bytes data);
    event TransactionCancelled(uint256 indexed txId);

    ///////////////////////////
    //// STATE VARIABLES ////
    ///////////////////////////

    address public owner;

    /////////////////////
    //// CONSTANTS ////
    /////////////////////

    uint256 public constant DELAY = 1 days;

    ///////////////////////
    //// CONSTRUCTOR ////
    ///////////////////////

    constructor() {
        owner = msg.sender;
    }

    //////////////////
    //// STRUCT ////
    //////////////////

    struct Queue {
        address target;
        bytes data;
        uint256 executeAfter;
        bool executed;
    }

    ///////////////////
    //// MAPPING ////
    ///////////////////

    mapping(uint256 => Queue) public queuedTransactions;

    ///////////////////////////
    //// STATE VARIABLES ////
    //////////////////////////

    uint256 public txCount;

    /////////////////////
    //// MODIFIERS ////
    /////////////////////

    modifier onlyOwner() {
        if (msg.sender != owner) revert Timelock__NotOwner();
        _;
    }

    //////////////////////
    ///// FUNCTIONS ////
    //////////////////////

    function queueTransaction(address target, bytes calldata data) external onlyOwner returns (uint256) {
        txCount++;

        if (target == address(0)) revert Timelock__InvalidTarget();

        uint256 executeAfter = block.timestamp + DELAY;

        queuedTransactions[txCount] = Queue({target: target, data: data, executeAfter: executeAfter, executed: false});

        emit TransactionQueued(txCount, target, data, executeAfter);

        return txCount;
    }

    function executeTransaction(uint256 txId) external onlyOwner {
        if (txId == 0 || txId > txCount) {
            revert Timelock__InvalidTxId();
        }

        Queue storage txData = queuedTransactions[txId];

        if (txData.executed) revert Timelock__AlreadyExecuted();

        if (block.timestamp < txData.executeAfter) revert Timelock__TooEarly();

        txData.executed = true;

        (bool success,) = txData.target.call(txData.data);

        if (!success) revert Timelock__ExecutionFailed();

        emit TransactionExecuted(txId, txData.target, txData.data);
    }

    function cancelTransaction(uint256 txId) external onlyOwner {
        if (txId == 0 || txId > txCount) {
            revert Timelock__InvalidTxId();
        }

        emit TransactionCancelled(txId);

        delete queuedTransactions[txId];
    }
}
