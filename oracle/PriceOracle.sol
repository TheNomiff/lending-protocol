// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// This path now maps correctly through your foundry.toml
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract PriceOracle {
    error PriceOracle__InvalidPrice();
    error PriceOracle__StalePrice();
    error PriceOracle__NotOwner();
    error PriceOracle__InvalidOwner();
    error PriceOracle__InvalidFeed();
    error PriceOracle__Paused();

    AggregatorV3Interface public priceFeed;

    address public immutable owner;
    bool public paused;

    uint256 public constant FEED_PRECISION = 1e8;
    uint256 public staleTime = 1 hours;

    constructor(address _feed, address _owner) {
        if (_feed == address(0)) revert PriceOracle__InvalidFeed();

        if (_owner == address(0)) revert PriceOracle__InvalidOwner();

        owner = _owner;

        priceFeed = AggregatorV3Interface(_feed);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert PriceOracle__NotOwner();
        _;
    }

    modifier notPaused() {
        if (paused) revert PriceOracle__Paused();
        _;
    }

    function getPrice() public view notPaused returns (uint256) {
        // latestRoundData returns 5 values, we only need the 2nd one (price)
        (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();

        if (price <= 0) revert PriceOracle__InvalidPrice();

        // stale check (1 hour example)
        if (block.timestamp - updatedAt > staleTime)
            revert PriceOracle__StalePrice();

        // Chainlink prices are usually 8 decimals, so we cast to uint256
        return uint256(price);
    }

    function getETHValueInUSD(uint256 ethAmount) public view returns (uint256) {
        uint256 price = getPrice();

        return (ethAmount * price) / FEED_PRECISION;
    }

    function getUSDToETH(uint256 usdAmount) public view returns (uint256) {
        uint256 price = getPrice();

        return (usdAmount * FEED_PRECISION) / price;
    }

    /////////////////////////
    //// ADMIN CONTROL ////
    ////////////////////////

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function setStaleTime(uint256 newStaleTime) external onlyOwner {
        staleTime = newStaleTime;
    }

    /////////////////////////////////////////
    //// SET NEW PRICE FEED FOR FUTURE ////
    ////////////////////////////////////////

    function setPriceFeed(address newFeed) external onlyOwner {
        if (newFeed == address(0)) revert PriceOracle__InvalidFeed();

        priceFeed = AggregatorV3Interface(newFeed);
    }
}
