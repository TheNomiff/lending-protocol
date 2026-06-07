// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OracleTestBase} from "../../utils/OracleTestBase.t.sol";

contract PriceOracleConversionTest is OracleTestBase {
    function testETHToUSDConversion() public view {
        uint256 ethAmount = 10 ether;

        uint256 actualUsdValue = oracle.getETHValueInUSD(ethAmount);

        uint256 expectedUsdValue = 20_000 ether;

        assertEq(actualUsdValue, expectedUsdValue);
    }

    function testUSDToETHConversion() public view {
        uint256 usdAmount = 20_000 ether;

        uint256 actualEthAmount = oracle.getUSDToETH(usdAmount);

        uint256 expectedEthAmount = 10 ether;

        assertEq(actualEthAmount, expectedEthAmount);
    }

    function testConversionUsesLatestPrice() public {
        uint256 ethAmount = 10 ether;
        uint256 standardPrice = oracle.getETHValueInUSD(ethAmount);

        assertEq(standardPrice, 20_000 ether);

        int256 newPrice = 3000e8;

        _updatePrice(newPrice);

        assertEq(oracle.getPrice(), 3000e8);

        uint256 updatedPrice = oracle.getETHValueInUSD(ethAmount);
        uint256 expectedNewPrice = 30_000 ether;

        assertEq(updatedPrice, expectedNewPrice);
    }
}
