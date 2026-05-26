// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    //////////////////
    //// ERRORS ////
    //////////////////

    error Timelock__NotOwner();
    error Timelock__TooEarly();
    error Timelock__AlreadyExecuted();

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

    ///////////////////////
    ///// ////
    ///////////////////////

    function queueTransaction(address target, bytes calldata data) external onlyOwner returns (uint256) {
        txCount++;

        queuedTransactions[txCount] =
            Queue({target: target, data: data, executeAfter: block.timestamp + DELAY, executed: false});

        return txCount;
    }

    function executeTransaction(uint256 txId) external onlyOwner {
        Queue storage txData = queuedTransactions[txId];

        if (txData.executed) revert Timelock__AlreadyExecuted();

        if (block.timestamp < txData.executeAfter) {
            revert Timelock__TooEarly();
        }

        txData.executed = true;

        (bool success,) = txData.target.call(txData.data);

        require(success, "Execution failed");
    }
}
