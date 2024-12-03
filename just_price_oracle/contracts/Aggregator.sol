// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;
import '@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './interfaces/IUniswapV3SwapRouter.sol';
import './interfaces/IUniswapV2Router.sol';
import './interfaces/IAggregator.sol';

/**
 * @title Aggregator contract
 * @author dev
 * @notice This contract is an aggregator contract which configures strategies for token pairs to enable token swaps.
 * It serves as an interface to interact with different types of liquidity pools and reserves to provide the most efficient
 * price for users wanting to swap tokens. It relies on pre-configured strategies which are set by contract admins.
 */
contract Aggregator is IAggregator, Ownable, AccessControlEnumerable {
    using SafeERC20 for IERC20;

    /// @notice The slippage value accepted during exchange
    uint256 private _slippage = 50;
    /// @notice The base exchange ratio
    uint256 constant BASE_RATIO = 10000;
    /// @notice The exchange deadline period
    uint256 constant DEADLINE = 1 minutes;
    /// @notice The router configuration array
    address[] private _cfg;
    /// @notice Token exchange strategy
    mapping(bytes32 => Strategy) private _strategies;

    /// @notice Emitted when owner updates the slippage
    /// @param _newSlippage The new slippage value
    event UpdateSlippage(uint256 _newSlippage);

    constructor(address[] memory initCfg, address initMultiSigWallet) {
        _cfg = initCfg;
        transferOwnership(initMultiSigWallet);
    }

    /// @inheritdoc IAggregator
    function addRouter(address _newRouter) external onlyOwner {
        _cfg.push(_newRouter);
    }

    /// @inheritdoc IAggregator
    function strategies(address tokenIn, address tokenOut) external view returns (Strategy memory) {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn, tokenOut));
        return _strategies[hash];
    }

    function getCfg() external view returns (address[] memory) {
        return _cfg;
    }

    /// @inheritdoc IAggregator
    function updateSlippage(uint256 _newSlippage) external onlyOwner {
        require(_newSlippage <= 500, 'slippage <= 5%');
        _slippage = _newSlippage;
        emit UpdateSlippage(_newSlippage);
    }

    /// @inheritdoc IAggregator
    function getSlippage() external view returns (uint256 slippage) {
        return _slippage;
    }

    /// @inheritdoc IAggregator
    function updateUniV2Strategy(address tokenIn, address tokenOut, UniV2Data[] calldata datas) external onlyOwner {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn, tokenOut));
        Strategy storage str = _strategies[hash];
        uint256 v2DataLen = str.v2Data.length;
        require(v2DataLen == 0 || v2DataLen == datas.length, 'dataLen error');
        for (uint128 i; i < datas.length; i++) {
            if (i < v2DataLen && v2DataLen > 0) {
                str.totalRatio -= str.v2Data[i].ratio;
                str.v2Data[i].ratio = datas[i].ratio;
            } else if (v2DataLen == 0) {
                str.v2Data.push(datas[i]);
            }
            str.totalRatio += datas[i].ratio;
        }
    }

    /// @inheritdoc IAggregator
    function updateUniV3Strategy(address tokenIn, address tokenOut, UniV3Data[] calldata datas) external onlyOwner {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn, tokenOut));
        Strategy storage str = _strategies[hash];
        uint256 v3DataLen = str.v3Data.length;
        require(v3DataLen <= datas.length, 'dataLen error');
        for (uint128 i; i < datas.length; i++) {
            if (i < v3DataLen && v3DataLen > 0) {
                str.totalRatio -= str.v3Data[i].ratio;
                str.v3Data[i].ratio = datas[i].ratio;
            } else if (v3DataLen == 0) {
                str.v3Data.push(datas[i]);
            }
            str.totalRatio += datas[i].ratio;
        }
    }
    /// @inheritdoc IAggregator
    function exactOutput(
        address tokenIn,
        uint256 amountInMax,
        address tokenOut,
        uint256 amountOut
    ) external returns (uint256 inAmount) {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn, tokenOut));
        Strategy memory str = _strategies[hash];
        require(str.totalRatio == 10000, 'total ratio incorrect');
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountInMax);
        if (str.v2Data.length > 0) {
            inAmount += _uniV2OutputSwap(str, tokenIn, amountOut, amountInMax, tokenOut, str.v3Data.length == 0);
        }
        if (str.v3Data.length > 0) {
            inAmount += _uniV3OutputSwap(str, tokenIn, amountOut, amountInMax, tokenOut, true);
        }
        if (amountInMax > inAmount) {
            IERC20(tokenIn).safeTransfer(msg.sender, amountInMax - inAmount);
        }
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
    }

    /// @inheritdoc IAggregator
    function exactInput(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOutMin
    ) external returns (uint256 outAmount) {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn, tokenOut));
        Strategy memory str = _strategies[hash];
        require(str.totalRatio == 10000, 'total ratio incorrect');
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        if (str.v2Data.length > 0) {
            outAmount += _uniV2InputSwap(str, tokenIn, amountIn, amountOutMin, str.v3Data.length == 0);
        }
        if (str.v3Data.length > 0) {
            outAmount += _uniV3InputSwap(str, tokenIn, amountIn, amountOutMin, true);
        }
        IERC20(tokenOut).safeTransfer(msg.sender, outAmount);
    }

    /// @dev Internal function execution occurs only when the user needs to swap for a specified number of tokenOut and there is a corresponding uniV3 strategy
    /// @param str The current exchange strategy being executed
    /// @param tokenIn The token address paid out during exchange
    /// @param amountOut The required amount of tokenOut to get back
    /// @param amountInMax The maximum amount of tokenIn to pay
    /// @return returnAmount Amount of tokenIn paid out using the uniV3 strategy
    function _uniV3OutputSwap(
        Strategy memory str,
        address tokenIn,
        uint256 amountOut,
        uint256 amountInMax,
        address tokenOut,
        bool isLastSwap
    ) internal returns (uint256 returnAmount) {
        IUniV3SwapRouter.ExactOutputParams memory para;
        uint validStratLen = _getStrategyLen(str);
        uint validCount;
        for (uint i = 0; i < str.v3Data.length; i++) {
            if (str.v3Data[i].ratio == 0) continue;
            para.path = str.v3Data[i].path;
            para.recipient = address(this);
            para.deadline = block.timestamp + DEADLINE;
            if (i == (validStratLen - 1) && isLastSwap) {
                para.amountOut = amountOut - IERC20(tokenOut).balanceOf(address(this));
                para.amountInMaximum = IERC20(tokenIn).balanceOf(address(this));
            } else {
                para.amountOut = (amountOut * str.v3Data[i].ratio) / BASE_RATIO;
                para.amountInMaximum = (amountInMax * str.v3Data[i].ratio) / BASE_RATIO;
            }
            // router = _cfg[uint256(str.v3Data[i].index)]
            IERC20(tokenIn).approve(_cfg[uint256(str.v3Data[i].index)], para.amountInMaximum);
            returnAmount += IUniV3SwapRouter(_cfg[uint256(str.v3Data[i].index)]).exactOutput(para);
             validCount = validCount + 1;
        }
    }

    /// @dev Internal function execution occurs only when the user needs to swap for a specified number of tokenOut and there is a corresponding uniV2 strategy
    /// @param str The current exchange strategy being executed
    /// @param tokenIn The token address paid out during exchange
    /// @param amountOut The required amount of tokenOut to get back
    /// @param amountInMax The maximum amount of tokenIn to pay
    /// @return inAmount Amount of tokenIn paid out using the uniV2 strategy
    function _uniV2OutputSwap(
        Strategy memory str,
        address tokenIn,
        uint256 amountOut,
        uint256 amountInMax,
        address tokenOut,
        bool isLastSwap
    ) internal returns (uint256 inAmount) {
        uint256 curAmountOut;
        uint256 curAmountInMax;
        uint validStratLen = _getStrategyLen(str);
        uint validCount;
        for (uint i = 0; i < str.v2Data.length; i++) {
            if (str.v2Data[i].ratio == 0) continue;
            if (i == (validStratLen - 1) && isLastSwap) {
                curAmountOut = amountOut - IERC20(tokenOut).balanceOf(address(this));
                curAmountInMax = IERC20(tokenIn).balanceOf(address(this));
            } else {
                curAmountOut = (amountOut * str.v2Data[i].ratio) / BASE_RATIO;
                curAmountInMax = (amountInMax * str.v2Data[i].ratio) / BASE_RATIO;
            }
            // router = _cfg[uint256(str.v2Data[i].index)]
            IERC20(tokenIn).approve(_cfg[uint256(str.v2Data[i].index)], amountInMax);
            inAmount += IUniswapV2Router(_cfg[uint256(str.v2Data[i].index)]).swapTokensForExactTokens(
                curAmountOut,
                curAmountInMax,
                str.v2Data[i].path,
                address(this),
                block.timestamp + DEADLINE
            )[0];
            validCount = validCount + 1;
        }
    }

    /// @dev The internal function is executed only when the user needs to use a specified number of tokenIn to exchange for tokenOut and there is a corresponding uniV3 strategy
    /// @param str The current exchange strategy being executed
    /// @param tokenIn The token address paid out during exchange
    /// @param amountIn The quantity of tokenIn paid in this exchange
    /// @param amountOutMin The minimum quantity of tokenOut that needs to be exchanged back in this transaction
    /// @return outAmount Amount of tokenOut exchanged using the uniV3 strategy
    function _uniV3InputSwap(
        Strategy memory str,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        bool isLastSwap
    ) internal returns (uint256 outAmount) {
        IUniV3SwapRouter.ExactInputParams memory para;
        uint validStratLen = _getStrategyLen(str);
        uint validCount;
        for (uint i = 0; i < str.v3Data.length; i++) {
            if (str.v3Data[i].ratio == 0) continue;
            para.path = str.v3Data[i].path;
            para.recipient = address(this);
            para.deadline = block.timestamp + DEADLINE;
            if (i == validStratLen - 1 && isLastSwap) {
                para.amountIn =  IERC20(tokenIn).balanceOf(address(this));
            } else {
                para.amountIn = (amountIn * str.v3Data[i].ratio) / BASE_RATIO;
            }
            para.amountOutMinimum = (amountOutMin * str.v3Data[i].ratio) / BASE_RATIO;
             // router = _cfg[uint256(str.v3Data[i].index)]
            IERC20(tokenIn).approve(_cfg[uint256(str.v3Data[i].index)], amountIn);
            outAmount += IUniV3SwapRouter(_cfg[uint256(str.v3Data[i].index)]).exactInput(para);
            validCount = validCount + 1;
        }
    }

    /// @dev The internal function is executed only when the user needs to use a specified number of tokenIn to exchange for tokenOut and there is a corresponding uniV2 strategy
    /// @param str The current exchange strategy being executed
    /// @param tokenIn The token address paid out during exchange
    /// @param amountIn The quantity of tokenIn paid in this exchange
    /// @param amountOutMin The minimum quantity of tokenOut that needs to be exchanged back in this transaction
    /// @return outAmount Amount of tokenOut exchanged using the uniV2 strategy
    function _uniV2InputSwap(
        Strategy memory str,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        bool isLastSwap
    ) internal returns (uint256 outAmount) {
        uint256 curAmountIn;
        uint validStratLen = _getStrategyLen(str);
        uint validCount;
        for (uint i = 0; i < str.v2Data.length; i++) {
            if (str.v2Data[i].ratio == 0) continue;
            if (validCount == validStratLen - 1 && isLastSwap) {
                curAmountIn = IERC20(tokenIn).balanceOf(address(this));
            } else {
                curAmountIn = (amountIn * str.v2Data[i].ratio) / BASE_RATIO;
            }
            // router = _cfg[uint256(str.v2Data[i].index)]
            IERC20(tokenIn).approve(_cfg[uint256(str.v2Data[i].index)], amountIn);
            uint[] memory amounts = IUniswapV2Router(_cfg[uint256(str.v2Data[i].index)]).swapExactTokensForTokens(
                curAmountIn,
                (amountOutMin * str.v2Data[i].ratio) / BASE_RATIO,
                str.v2Data[i].path,
                address(this),
                block.timestamp + DEADLINE
            );
            outAmount  = outAmount + amounts[amounts.length - 1];
            validCount = validCount + 1;
        }
    }

    function _getStrategyLen(Strategy memory str) internal pure returns(uint validLen) {
        for (uint i = 0; i < str.v2Data.length; i++) {
            if (str.v2Data[i].ratio == 0) continue;
            validLen = validLen +1 ;
        }
    }
}
