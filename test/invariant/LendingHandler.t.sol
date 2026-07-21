// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Lending} from "../../src/Lending.sol";

contract LendingHandler is Test {
    Lending internal immutable lending;

    address[] internal actors;
    address internal constant ETH_SENTINEL = address(0);

    constructor(Lending _lending) {
        lending = _lending;
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
        _writeDebugLog("pre-fix", "H2", "LendingHandler.t.sol:deposit", "deposit bounded", actor, amount, boundedAmount);
        // #endregion
        vm.deal(actor, boundedAmount);

        vm.prank(actor);
        lending.deposit{value: boundedAmount}(ETH_SENTINEL);
    }

    function borrow(uint256 actorIndex, uint256 amount) external {
        address actor = _actor(actorIndex);
        uint256 boundedAmount = bound(amount, 1 wei, 10 ether);

        vm.prank(actor);

        try lending.borrow(boundedAmount, ETH_SENTINEL) {} catch {}
    }

    function withdraw(uint256 actorIndex, uint256 amount) external {
        address actor = _actor(actorIndex);
        uint256 boundedAmount = bound(amount, 1 wei, 10 ether);

        vm.prank(actor);

        try lending.withdraw(boundedAmount, ETH_SENTINEL) {} catch {}
    }

    function repay(uint256 actorIndex, uint256 amount) external {
        address actor = _actor(actorIndex);
        uint256 boundedAmount = bound(amount, 1 wei, 10 ether);

        vm.deal(actor, boundedAmount);

        vm.prank(actor);

        try lending.repay{value: boundedAmount}(ETH_SENTINEL) {} catch {}
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
