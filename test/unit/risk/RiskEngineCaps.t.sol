// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RiskEngine} from "../../../src/engines/RiskEngine.sol";
import {RiskTestBase} from "../../utils/RiskTestBase.t.sol";

contract RiskEngineCapsTest is RiskTestBase {
    function testCanSupplyAtCap() public view {
        uint256 supplyAmount = riskEngine.supplyCap();
        bool canSupply = riskEngine.canSupply(0, supplyAmount);

        assertTrue(canSupply);
    }

    function testCanSupplyAboveCap() public view {
        uint256 supplyAmount = riskEngine.supplyCap() + 100 ether;
        bool canSupply = riskEngine.canSupply(0, supplyAmount);

        assertFalse(canSupply);
    }

    function testCanBorrowAtCap() public view {
        uint256 borrowCap = riskEngine.borrowCap();
        bool canBorrow = riskEngine.canGlobalBorrow(0, borrowCap);

        assertTrue(canBorrow);
    }

    function testCanBorrowAboveCap() public view {
        uint256 borrowCap = riskEngine.borrowCap() + 100 ether;
        bool canBorrow = riskEngine.canGlobalBorrow(0, borrowCap);

        assertFalse(canBorrow);
    }

    function testUpdateSupplyCap() public {
        uint256 newCap = 2000 ether;

        riskEngine.updateSupplyCap(newCap);

        assertEq(riskEngine.supplyCap(), newCap);
    }

    function testUpdateBorrowCap() public {
        uint256 newCap = 1000 ether;

        riskEngine.updateBorrowCap(newCap);

        assertEq(riskEngine.borrowCap(), newCap);
    }

    function testNonOwnerCannotUpdateSupplyCap() public {
        address attacker = makeAddr("Attacker");
        uint256 newCap = 2000 ether;

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__NotOwner.selector);

        riskEngine.updateSupplyCap(newCap);
    }

    function testNonOwnerCannotUpdateBorrowCap() public {
        address attacker = makeAddr("Attacker");
        uint256 newCap = 1000 ether;

        vm.prank(attacker);
        vm.expectRevert(RiskEngine.RiskEngine__NotOwner.selector);

        riskEngine.updateBorrowCap(newCap);
    }

    function testUpdateSupplyCapReverts() public {
        uint256 newCap = 0;

        vm.expectRevert(RiskEngine.RiskEngine__InvalidCaps.selector);

        riskEngine.updateSupplyCap(newCap);
    }

    function testUpdateBorrowCapReverts() public {
        uint256 newCap = 0;

        vm.expectRevert(RiskEngine.RiskEngine__InvalidCaps.selector);

        riskEngine.updateBorrowCap(newCap);
    }
}
