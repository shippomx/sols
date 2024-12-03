// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

interface IAggregator {
    /// @param path The current exchange path of uniV3
    /// @param ratio The exchange ratio of the current router in the whole strategy
    /// @param index The index of the current router in the router array
    struct UniV3Data {
        bytes path;
        uint256 ratio;
        uint256 index;
    }

    /// @param path The current exchange path of uniV2
    /// @param ratio The exchange ratio of the current router in the whole strategy
    /// @param index The index of the current router in the router array
    struct UniV2Data {
        address[] path;
        uint256 ratio;
        uint256 index;
    }

    /// @param totalRatio Total percentage of the current strategy
    /// @param v2Data Using uniV2 configuration in the current strategy
    /// @param v3Data Using uniV3 configuration in the current strategy
    struct Strategy {
        uint256 totalRatio;
        UniV2Data[] v2Data;
        UniV3Data[] v3Data;
    }

    /// @dev Obtain current slippage value
    /// @return slippage Current slippage value
    function getSlippage() external view returns (uint256 slippage);

    /// @notice Execute the strategy to pay out tokenIn to acquire a specified amount of tokenOut
    /// @param tokenIn The token address paid out during exchange
    /// @param amountInMax The maximum number of tokenIn to be paid out
    /// @param tokenOut The token address acquired during exchange
    /// @param amountOut The number of tokenOut to be obtained
    /// @return inAmount The number of tokenIn paid out in this exchange
    function exactOutput(
        address tokenIn,
        uint256 amountInMax,
        address tokenOut,
        uint256 amountOut
    ) external returns (uint256 inAmount);

    /// @notice Implement the strategy to pay out a specific amount of tokenIn to get tokenOut
    /// @param tokenIn The token address paid out during exchange
    /// @param amountIn The number of tokenIn to be paid out
    /// @param tokenOut The token address acquired during exchange
    /// @param amountOutMin The minimum  number of tokenOut to be obtained
    /// @return outAmount The number of tokenOut acquired in this exchange
    function exactInput(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOutMin
    ) external returns (uint256 outAmount);

    /// @notice Update the acceptable slippage value in the exchange
    /// @param _newSlippage New slippage value
    function updateSlippage(uint256 _newSlippage) external;

    /// @notice Update token pair strategy for UniV3 type router in the exchange
    /// @param tokenIn The token address paid out during exchange
    /// @param tokenOut The token address acquired during exchange
    /// @param datas About the new exchange strategy for this token pair
    function updateUniV3Strategy(
        address tokenIn,
        address tokenOut,
        UniV3Data[] calldata datas
    ) external;

    /// @notice Update token pair strategy for UniV2 type router in the exchange
    /// @param tokenIn The token address paid out during exchange
    /// @param tokenOut The token address acquired during exchange
    /// @param datas About the new exchange strategy for this token pair
    function updateUniV2Strategy(
        address tokenIn,
        address tokenOut,
        UniV2Data[] calldata datas
    ) external;

    /// @notice Contract administrator adds new available router
    /// @param _newRouter The router address added this time, which will be used to execute corresponding token conversion
    function addRouter(address _newRouter) external;

    /// @notice The current token pair settings for strategy
    /// @param tokenIn The token address paid out during exchange
    /// @param tokenOut The token address acquired during exchange
    /// @return Current token pair strategy
    function strategies(
        address tokenIn,
        address tokenOut
    ) external view returns (Strategy memory);

    function getCfg() external view returns (address[] memory);
}
