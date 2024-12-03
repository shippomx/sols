// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

/// @title Fast Price Feed Interface
/// @notice Provides interface for the fast price feed functionality, allowing for efficient price updates and access.
interface IFastPriceFeed {

    /// @dev Enum representing the various types of price feed plans.
    enum Plan {
        DEX,        // Decentralized Exchange
        CHAINLINK,  // Chainlink Oracle
        PYTH       // Pyth Network
    }

    /// @dev Struct representing the price limits for an asset.
    struct PriceLimit {
        uint256 min; // Minimum price
        uint256 max; // Maximum price
    }

    /// @notice Emitted when the administrator set a new timelimit for the asset.
    /// @param asset The address of the asset.
    /// @param oldTimelimit The previous value of timelimit
    /// @param newTimelimit The value of timelimit updated this time
    event SetPythTimelimit(address asset,  uint256 oldTimelimit, uint256 newTimelimit);

    /// @notice Emitted when the price limits for an asset are set.
    /// @param asset The address of the asset.
    /// @param prices The price limits for the asset.
    event SetPriceLimit(address indexed asset, PriceLimit prices);

    /// @notice Emitted when the DEX price feed for an asset is set.
    /// @param asset The address of the asset.
    /// @param univ3Pool The address of the Uniswap v3 pool.
    event SetDexPriceFeed(address indexed asset, address indexed univ3Pool);

    /// @notice Emitted when the TWAP interval for an asset is updated.
    /// @param asset The address of the asset.
    /// @param previous The previous TWAP interval.
    /// @param present The new TWAP interval.
    event SetTwapInterval(address indexed asset, uint32 previous, uint32 present);

    /// @notice Emitted when the Chainlink aggregator for an asset is set.
    /// @param asset The address of the asset.
    /// @param aggregator The address of the Chainlink aggregator.
    event SetChainlinkAggregator(address indexed asset, address indexed aggregator);

    /// @notice Emitted when the Pyth price feed for an asset is initialized.
    /// @param asset The address of the asset.
    /// @param oracleAddr The address of the Pyth oracle.
    /// @param priceFeed The identifier for the Pyth price feed.
    event InitPyhonPriceFeed(address indexed asset, address indexed oracleAddr, bytes32 priceFeed);
    
    /// @notice Retrieves the current price for a given asset.
    /// @param _asset The address of the asset.
    /// @return price The current price of the asset.
    function getPrice(address _asset) external view returns (uint256 price);
}
