// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskTestBase} from "../../utils/RiskTestBase.t.sol";

contract RiskEngineWithdrawTest is RiskTestBase {
    function testCanWithdrawReturnsTrue() public view {
        uint256 remainingCollateralUsd = 90 ether;
        uint256 debtUsd = 40 ether;

        bool canWithdraw = riskEngine.canWithdraw(remainingCollateralUsd, debtUsd);

        assertTrue(canWithdraw);
    }

    function testCanWithdrawReturnsFalse() public view {
        uint256 remainingCollateralUsd = 70 ether;
        uint256 debtUsd = 40 ether;

        bool canWithdraw = riskEngine.canWithdraw(remainingCollateralUsd, debtUsd);

        assertFalse(canWithdraw);
    }

    function testCanWithdrawAtExactLimit() public view {
        uint256 remainingCollateralUsd = 100 ether;
        uint256 debtUsd = 50 ether;

        bool canWithdraw = riskEngine.canWithdraw(remainingCollateralUsd, debtUsd);

        assertTrue(canWithdraw);
    }
}
