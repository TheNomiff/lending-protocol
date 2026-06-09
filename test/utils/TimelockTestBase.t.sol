// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Timelock} from "../../src/governance/Timelock.sol";

/// @notice Minimal call target for exercising timelock execution paths.
contract MockTarget {
    uint256 public value;
    bool public shouldRevert;

    function setValue(uint256 newValue) external {
        if (shouldRevert) revert();
        value = newValue;
    }

    function setShouldRevert(bool revertOnCall) external {
        shouldRevert = revertOnCall;
    }
}

abstract contract TimelockTestBase is Test {
    Timelock internal timelock;
    MockTarget internal mockTarget;

    address internal owner = address(this);
    address internal constant NON_OWNER = address(999);

    uint256 internal constant DELAY = 1 days;

    function setUp() public virtual {
        timelock = new Timelock();
        mockTarget = new MockTarget();
    }

    //////////////////////////////
    ////// HELPER FUNCTIONS //////
    //////////////////////////////

    function _queueTransaction(address target, bytes memory data) internal returns (uint256 txId) {
        return timelock.queueTransaction(target, data);
    }

    function _executeTransaction(uint256 txId) internal {
        timelock.executeTransaction(txId);
    }

    function _cancelTransaction(uint256 txId) internal {
        timelock.cancelTransaction(txId);
    }

    function _warpPastDelay() internal {
        vm.warp(block.timestamp + DELAY + 1);
    }

    function _warpToTimestamp(uint256 timestamp) internal {
        vm.warp(timestamp);
    }

    function _encodeSetValue(uint256 newValue) internal pure returns (bytes memory) {
        return abi.encodeCall(MockTarget.setValue, (newValue));
    }

    function _queueSetValue(uint256 newValue) internal returns (uint256 txId) {
        return _queueTransaction(address(mockTarget), _encodeSetValue(newValue));
    }

    function _queueAndWarpSetValue(uint256 newValue) internal returns (uint256 txId) {
        txId = _queueSetValue(newValue);
        _warpPastDelay();
    }
}
