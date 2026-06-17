// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LiquidationTestBase} from "../../utils/LiquidationTestBase.t.sol";
import {RiskEngine} from "../../../src/engines/RiskEngine.sol";

contract LiquidationEngineExecutionTest is LiquidationTestBase {
    function testCanLiquidateReturnsFalseForHealthyPosition() public view {
        uint256 hf = 1e18;

        assertFalse(liquidationEngine.canLiquidate(hf));
    }

    function testCanLiquidateReturnsTrueForUnhealthyPosition() public view {
        uint256 hf = 0.8e18;

        assertTrue(liquidationEngine.canLiquidate(hf));
    }

    function testCanLiquidateReturnsFalseAtExactMinimumHF() public view {
        uint256 hf = riskEngine.minHealthFactor();

        assertFalse(liquidationEngine.canLiquidate(hf));
    }

    function testRemainingDebtAfterLiquidation() public view {
        uint256 remaining = liquidationEngine.remainingDebtAfterLiquidation(100 ether, 40 ether);

        assertEq(remaining, 60 ether);
    }

    function testRemainingDebtReturnsZeroWhenFullyRepaid() public view {
        uint256 remaining = liquidationEngine.remainingDebtAfterLiquidation(100 ether, 100 ether);

        assertEq(remaining, 0);
    }

    function testRemainingDebtReturnsZeroWhenOverRepaid() public view {
        uint256 remaining = liquidationEngine.remainingDebtAfterLiquidation(100 ether, 150 ether);

        assertEq(remaining, 0);
    }

    function testRemainingDebtReturnsZeroForZeroDebt() public view {
        uint256 remaining = liquidationEngine.remainingDebtAfterLiquidation(0 ether, 10 ether);

        assertEq(remaining, 0);
    }

    function testRemainingCollateralAfterSeizure() public view {
        uint256 remaining = liquidationEngine.remainingCollateralAfterSeizure(100 ether, 20 ether);

        assertEq(remaining, 80 ether);
    }

    function testRemainingCollateralReturnsZeroWhenFullySeized() public view {
        uint256 remaining = liquidationEngine.remainingCollateralAfterSeizure(100 ether, 100 ether);

        assertEq(remaining, 0);
    }

    function testRemainingCollateralReturnsZeroWhenOverSeized() public view {
        uint256 remaining = liquidationEngine.remainingCollateralAfterSeizure(100 ether, 120 ether);

        assertEq(remaining, 0);
    }

    function testRemainingCollateralReturnsZeroForZeroCollateral() public view {
        uint256 remaining = liquidationEngine.remainingCollateralAfterSeizure(0, 10 ether);

        assertEq(remaining, 0);
    }
}
