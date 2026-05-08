// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Landing} from "../../src/Landing.sol";

contract LandingHandler is Test {
    Landing internal immutable landing;

    address[] internal actors;
    constructor(Landing _landing) {
        landing = _landing;
        actors.push(address(11));
        actors.push(address(12));
        actors.push(address(13));
        actors.push(address(14));
    }

    receive() external payable {}

    function deposit(uint256 actorIndex, uint256 amount) external {
        address actor = _actor(actorIndex);
        uint256 boundedAmount = bound(amount, 1 wei, 20 ether);
        // #region agent log
        _writeDebugLog(
            "pre-fix",
            "H2",
            "LandingHandler.t.sol:deposit",
            "deposit bounded",
            actor,
            amount,
            boundedAmount
        );
        // #endregion
        vm.deal(actor, boundedAmount);

        vm.prank(actor);
        landing.deposit{value: boundedAmount}();
    }

    function borrow(uint256 actorIndex, uint256 amount) external {
        address actor = _actor(actorIndex);
        uint256 boundedAmount = bound(amount, 1 wei, 10 ether);
        // #region agent log
        _writeDebugLog(
            "pre-fix",
            "H3",
            "LandingHandler.t.sol:borrow",
            "borrow bounded",
            actor,
            amount,
            boundedAmount
        );
        // #endregion
        vm.prank(actor);
        try landing.borrow(boundedAmount) {} catch {}
    }

    function withdraw(uint256 actorIndex, uint256 amount) external {
        address actor = _actor(actorIndex);
        uint256 boundedAmount = bound(amount, 1 wei, 10 ether);
        // #region agent log
        _writeDebugLog(
            "pre-fix",
            "H4",
            "LandingHandler.t.sol:withdraw",
            "withdraw bounded",
            actor,
            amount,
            boundedAmount
        );
        // #endregion
        vm.prank(actor);
        try landing.withdraw(boundedAmount) {} catch {}
    }

    function repay(uint256 actorIndex, uint256 amount) external {
        address actor = _actor(actorIndex);
        uint256 boundedAmount = bound(amount, 1 wei, 10 ether);
        // #region agent log
        _writeDebugLog(
            "pre-fix",
            "H5",
            "LandingHandler.t.sol:repay",
            "repay bounded",
            actor,
            amount,
            boundedAmount
        );
        // #endregion
        vm.deal(actor, boundedAmount);
        vm.prank(actor);
        try landing.repay{value: boundedAmount}() {} catch {}
    }

    function _actor(uint256 actorIndex) internal view returns (address) {
        return actors[actorIndex % actors.length];
    }

    function _writeDebugLog(
        string memory runId,
        string memory hypothesisId,
        string memory location,
        string memory message,
        address actor,
        uint256 rawAmount,
        uint256 boundedAmount
    ) internal {
        vm.writeLine(
            "debug-d48aa9.log",
            string(
                abi.encodePacked(
                    '{"sessionId":"d48aa9","runId":"',
                    runId,
                    '","hypothesisId":"',
                    hypothesisId,
                    '","location":"',
                    location,
                    '","message":"',
                    message,
                    '","data":{"actor":"',
                    vm.toString(actor),
                    '","rawAmount":"',
                    vm.toString(rawAmount),
                    '","boundedAmount":"',
                    vm.toString(boundedAmount),
                    '"},"timestamp":',
                    vm.toString(block.timestamp),
                    "}"
                )
            )
        );
    }

}
