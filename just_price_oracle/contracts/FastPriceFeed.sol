// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import '@pythnetwork/pyth-sdk-solidity/IPyth.sol';
import '@pythnetwork/pyth-sdk-solidity/PythStructs.sol';
import './interfaces/IUniswapV3Pool.sol';
import './interfaces/IFastPriceFeed.sol';

// import 'hardhat/console.sol';

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = a * b
            // Compute the product mod 2**256 and mod 2**256 - 1
            // then use the Chinese Remainder Theorem to reconstruct
            // the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2**256 + prod0
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(a, b, not(0))
                prod0 := mul(a, b)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division
            if (prod1 == 0) {
                require(denominator > 0);
                assembly {
                    result := div(prod0, denominator)
                }
                return result;
            }

            // Make sure the result is less than 2**256.
            // Also prevents denominator == 0
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0]
            // Compute remainder using mulmod
            uint256 remainder;
            assembly {
                remainder := mulmod(a, b, denominator)
            }
            // Subtract 256 bit number from 512 bit number
            assembly {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator
            // Compute largest power of two divisor of denominator.
            // Always >= 1.
            uint256 twos = (0 - denominator) & denominator;
            // Divide denominator by power of two
            assembly {
                denominator := div(denominator, twos)
            }

            // Divide [prod1 prod0] by the factors of two
            assembly {
                prod0 := div(prod0, twos)
            }
            // Shift in bits from prod1 into prod0. For this we need
            // to flip `twos` such that it is 2**256 / twos.
            // If twos is zero, then it becomes one
            assembly {
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;

            // Invert denominator mod 2**256
            // Now that denominator is an odd number, it has an inverse
            // modulo 2**256 such that denominator * inv = 1 mod 2**256.
            // Compute the inverse by starting with a seed that is correct
            // correct for four bits. That is, denominator * inv = 1 mod 2**4
            uint256 inv = (3 * denominator) ^ 2;
            // Now use Newton-Raphson iteration to improve the precision.
            // Thanks to Hensel's lifting lemma, this also works in modular
            // arithmetic, doubling the correct bits in each step.
            inv *= 2 - denominator * inv; // inverse mod 2**8
            inv *= 2 - denominator * inv; // inverse mod 2**16
            inv *= 2 - denominator * inv; // inverse mod 2**32
            inv *= 2 - denominator * inv; // inverse mod 2**64
            inv *= 2 - denominator * inv; // inverse mod 2**128
            inv *= 2 - denominator * inv; // inverse mod 2**256

            // Because the division is now exact we can divide by multiplying
            // with the modular inverse of denominator. This will give us the
            // correct result modulo 2**256. Since the precoditions guarantee
            // that the outcome is less than 2**256, this is the final result.
            // We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inv;
            return result;
        }
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            result = mulDiv(a, b, denominator);
            if (mulmod(a, b, denominator) > 0) {
                require(result < type(uint256).max);
                result++;
            }
        }
    }
}

/// @title Math library for computing sqrt prices from ticks and vice versa
/// @notice Computes sqrt price for ticks of size 1.0001, i.e. sqrt(1.0001^tick) as fixed point Q64.96 numbers. Supports
/// prices between 2**-128 and 2**128
library TickMath {
    /// @dev The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-128
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
    uint24 internal constant MAX_TICK = 887272;

    /// @notice Calculates sqrt(1.0001^tick) * 2^96
    /// @dev Throws if |tick| > max tick
    /// @param tick The input tick for the above formula
    /// @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the ratio of the two assets (token1/token0)
    /// at the given tick
    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
        require(absTick <= uint256(MAX_TICK), 'T');

        uint256 ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;

        // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
        // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
        // we round up in the division so getTickAtSqrtRatio of the output price is always consistent
        sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }
}

/// @title Fast Price Feed Contract
/// @notice Provides rapid access to price feeds, supporting multiple price sources including on-chain and off-chain data.
/// @dev Extends AccessControlEnumerable, utilizing OpenZeppelin libraries for secure math operations and ERC20 interactions.
contract FastPriceFeed is IFastPriceFeed, AccessControlEnumerable {
    using SafeMath for uint256;

    uint32 public constant MIN_INTERVA = 5 minutes;
    uint32 public constant MAX_INTERVA = 24 hours;
    uint256 private constant _priceDecimals = 1e18;

    mapping(address => bool) private _isSupported;
    mapping(address => uint32) private _twapIntervals;

    mapping(address => Plan) private _plans;
    mapping(address => PriceLimit) private _priceLimits;

    mapping(address => bytes32) internal _pythAssetPriceIdMap;

    mapping(address => uint256) internal _assetTime;
    mapping(address => address[3]) internal _assetMap;

    constructor(address _initMultiSigWallet) {
        _grantRole(DEFAULT_ADMIN_ROLE, _initMultiSigWallet);
    }

    modifier isSupportedToken(address _asset) {
        require(_isSupported[_asset], 'invalid token');
        _;
    }

    /// @notice Initializes price feed for a Pyth oracle
    /// @dev Sets up the Pyth oracle price feed by mapping asset to its price ID and oracle address, and setting a time limit for price freshness.
    /// @param _asset The asset for which to initialize the price feed
    /// @param _oracleAddr The address of the Pyth oracle providing the price feed
    /// @param _priceId The price ID in the Pyth oracle for the given asset
    /// @param _timelimit The time limit in seconds within which the price is considered fresh
    function initPythonPriceFeed(address _asset, address _oracleAddr, bytes32 _priceId, uint256 _timelimit) internal {
        _pythAssetPriceIdMap[_asset] = _priceId;
        _assetMap[_asset][2] = _oracleAddr;
        _assetTime[_asset] = _timelimit;
        //check priceId
        PythStructs.Price memory _price = IPyth(_oracleAddr).getPriceNoOlderThan(_priceId, _timelimit);
        require(_price.price > 0, 'priceId error');
        emit InitPyhonPriceFeed(_asset, _oracleAddr, _priceId);
    }

    /// @notice Retrieves the Pyth oracle price for a given token
    /// @dev Fetches the latest price from the Pyth oracle, ensuring it's within the set timelimit and adjusting for decimals.
    /// @param _token The token address for which to fetch the price
    /// @return price The latest price of the token from the Pyth oracle, adjusted to the contract's price decimals
    function getPytPrice(address _token) public view returns (uint256 price) {
        bytes32 priceId = _pythAssetPriceIdMap[_token];
        PythStructs.Price memory _price = IPyth(_assetMap[_token][2]).getPriceNoOlderThan(
            priceId,
            _assetTime[_token]
        );
        require(_price.expo < 0 && _price.price > 0,"pyth price error");
        uint32 expo = uint32(-_price.expo);
        uint64 pythPrice = uint64(_price.price);
        price = _priceDecimals.mul(pythPrice).div(10 ** expo);
        return price;
    }

    /// @notice Checks whether an asset is supported by the price feed
    /// @param _asset The address of the asset to check
    /// @return bool True if the asset is supported, false otherwise
    function isSupported(address _asset) external view returns (bool) {
        return _isSupported[_asset];
    }

    /// @notice Returns the TWAP interval for an asset
    /// @param _asset The address of the asset
    /// @return uint32 The TWAP interval in seconds
    function getTwapIntervals(address _asset) external view returns (uint32) {
        return _twapIntervals[_asset];
    }

    /// @notice Returns the oracle address associated with an asset
    /// @param _asset The address of the asset
    /// @return address The oracle address
    function getAssetFeedMap(address _asset) external view returns (address) {
        if (_plans[_asset] == Plan.DEX) {
            return _assetMap[_asset][0];
        } else if (_plans[_asset] == Plan.CHAINLINK) {
            return _assetMap[_asset][1];
        } else if (_plans[_asset] == Plan.PYTH) {
            return _assetMap[_asset][2];
        }
        return address(0);
    }

    /// @notice Returns the pricing plan for an asset
    /// @param _asset The address of the asset
    /// @return Plan The pricing plan
    function getPlans(address _asset) external view returns (Plan) {
        return _plans[_asset];
    }

    /// @notice Returns the price limits for an asset
    /// @param _asset The address of the asset
    /// @return PriceLimit The price limits
    function getPriceLimits(address _asset) external view returns (PriceLimit memory) {
        return _priceLimits[_asset];
    }

    /// @notice Sets new price limits for a batch of assets
    /// @dev Can only be called by accounts with the default admin role
    /// @param _assets An array of asset addresses
    /// @param _prices An array of new price limits
    function batchSetAssetPriceLimit(
        address[] memory _assets,
        PriceLimit[] memory _prices
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_assets.length == _prices.length, 'invalid params');
        for (uint32 i = 0; i < _assets.length; i++) {
            require(_isSupported[_assets[i]], 'invalid token');
            _priceLimits[_assets[i]] = _prices[i];
            emit SetPriceLimit(_assets[i], _prices[i]);
        }
    }

    /// @notice Administrator set a new timelimit for the asset.
    /// @param _asset The address of the asset.
    /// @param _timelimit The value of timelimit updated this time
    function setPythTimelimit(address _asset, uint256 _timelimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_isSupported[_asset], 'Oracle: do not support this token');
        require(_plans[_asset] == Plan.PYTH, 'setTwapInterval: Only pyth _asset');
        emit SetPythTimelimit(_asset, _assetTime[_asset], _timelimit);
        _assetTime[_asset] = _timelimit;
    }

    /// @notice The admin sets the UniV3 time period for the token
    /// @param _asset The token address for setting the time period this time
    /// @param _twapInterval The time period to be set for this time
    function setTwapInterval(address _asset, uint32 _twapInterval) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_isSupported[_asset], 'Oracle: do not support this token');
        require(_plans[_asset] == Plan.DEX, 'setTwapInterval: Only dex _asset');
        require(MAX_INTERVA >= _twapInterval && _twapInterval >= MIN_INTERVA, 'setTwapInterval: Invalid twapInterval');
        emit SetTwapInterval(_asset, _twapIntervals[_asset], _twapInterval);
        _twapIntervals[_asset] = _twapInterval;
    }

    /// @notice Add an asset in the price feed with new configurations
    /// @dev Can only be called by accounts with the default admin role
    /// @param _asset The address of the asset
    /// @param _assetPriceFeed The addresses of the asset's price feed oracle
    /// @param _assetPriceId The price ID (for Pyth oracle)
    /// @param _twapInterval The TWAP interval (for DEX oracle)
    /// @param _plan The pricing plan
    /// @param _timelimit The time limit for price validity (for Pyth oracle)
    function newAsset(
        address _asset,
        address[3] calldata _assetPriceFeed,
        bytes32 _assetPriceId, // only for pyth oracle
        uint32 _twapInterval,
        Plan _plan,
        uint256 _timelimit
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!_isSupported[_asset], 'already add');
        _isSupported[_asset] = true;
        _plans[_asset] = _plan;
        if (_assetPriceFeed[0] != address(0)) {
            initDexPriceFeed(_asset, _assetPriceFeed[0]);
            require(
                MAX_INTERVA >= _twapInterval && _twapInterval >= MIN_INTERVA,
                'setTwapInterval: Invalid twapInterval'
            );
            _twapIntervals[_asset] = _twapInterval;
        }
        if (_assetPriceFeed[1] != address(0)) {
            initChainlinkPriceFeed(_asset, _assetPriceFeed[1], _timelimit);
        }
        if (_assetPriceFeed[2] != address(0)) {
            initPythonPriceFeed(_asset, _assetPriceFeed[2], _assetPriceId, _timelimit);
        }
    }

    /// Update an asset in the price feed with new plan
    /// @dev Can only be called by accounts with the default admin role
    /// @param _asset The address of the asset
    /// @param _plan The pricing plan
    function switchPriceFeed(address _asset, Plan _plan) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_isSupported[_asset], 'unsupported asset');
        if (_plan == Plan.DEX) {
            require(_assetMap[_asset][0] != address(0), 'unsupported pricefeed');
        } else if (_plan == Plan.CHAINLINK) {
            require(_assetMap[_asset][1] != address(0), 'unsupported pricefeed');
        } else if (_plan == Plan.PYTH) {
            require(_assetMap[_asset][2] != address(0), 'unsupported pricefeed');
        }
        _plans[_asset] = _plan;
    }

    /// @notice Initializes Chainlink price feed for a given asset
    /// @param _asset The asset address to initialize the Chainlink price feed for
    /// @param _chainlink The Chainlink aggregator address
    /// @dev Internal function, checks that the Chainlink aggregator address is not zero and validates the aggregator
    function initChainlinkPriceFeed(address _asset, address _chainlink, uint256 _timelimit) internal {
        require(_chainlink != address(0), 'zero address');
        checkChainlinkAggregatorVallid(_chainlink, _timelimit);
        _assetMap[_asset][1] = _chainlink;
        _assetTime[_asset] = _timelimit;
        emit SetChainlinkAggregator(_asset, _chainlink);
    }

    /// @notice Initializes Dex price feed for a given asset using a Uniswap V3 Pool
    /// @param _asset The asset address to initialize the Dex price feed for
    /// @param _univ3Pool The Uniswap V3 Pool address
    /// @dev Internal function, checks that the Uniswap V3 Pool address is not zero
    function initDexPriceFeed(address _asset, address _univ3Pool) internal {
        require(_univ3Pool != address(0), 'UniV3 Pool: zore address is not allowed');
        _assetMap[_asset][0] = _univ3Pool;
        emit SetDexPriceFeed(_asset, _univ3Pool);
    }

    /// @notice Validates the Chainlink aggregator by ensuring it returns a positive price
    /// @param _pythAggregator The Chainlink aggregator address to validate
    /// @dev Internal view function, checks the validity of the Chainlink price feed
    function checkChainlinkAggregatorVallid(address _pythAggregator, uint256 _timelimit) internal view {
        AggregatorV3Interface aggregator = AggregatorV3Interface(_pythAggregator);
        (, int256 newPrice_, , uint256 updateAt, ) = aggregator.latestRoundData();
        require(newPrice_ > 0 && updateAt + _timelimit > block.timestamp, 'Price Feed: invalid Oracle');
    }

    /// @notice Retrieves the price for a given asset from its Dex price feed, using a TWAP calculation
    /// @param _asset The asset address to get the price for
    /// @return price The calculated asset price based on the Dex price feed
    /// @dev Internal view function, utilizes the Uniswap V3 Pool for the asset to compute the TWAP
    function getPriceFromDex(address _asset) internal view returns (uint256 price) {
        require(_isSupported[_asset], 'UniV3: oracle in mainnet not initialized yet!');
        address uniswapV3Pool = _assetMap[_asset][0];
        uint32 twapInterval = _twapIntervals[_asset];
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Pool);
        IUniswapV3Pool.Slot0 memory slot0;
        IUniswapV3Pool.Observation memory obs;
        slot0 = pool.slot0();
        obs = pool.observations((slot0.observationIndex + 1) % slot0.observationCardinality);
        if(!obs.initialized) {
            obs = pool.observations(0);
        }
        uint32 delta = uint32(block.timestamp) - obs.blockTimestamp;
        require(delta >= twapInterval, 'UniV3: token pool does not have enough transaction history in mainnet');
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapInterval;
        secondsAgos[1] = 0;
        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
            int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(twapInterval)))
        );
        price = mockDexPrice(pool, sqrtPriceX96, _asset);
        return price;
    }

    /// @notice Calculates a mock price for an asset based on sqrtPriceX96 from Uniswap V3 Pool
    /// @param _pool The Uniswap V3 Pool contract instance
    /// @param _sqrtPriceX96 The square root price from the Uniswap V3 Pool
    /// @param _asset The asset address to calculate the price for
    /// @return price The calculated mock price for the asset
    /// @dev Internal view function, computes the price based on the Uniswap V3 formula
    function mockDexPrice(
        IUniswapV3Pool _pool,
        uint160 _sqrtPriceX96,
        address _asset
    ) internal view returns (uint256 price) {
        address token0 = _pool.token0();
        address token1 = _pool.token1();
        uint8 decimal0 = ERC20(token0).decimals();
        uint8 decimal1 = ERC20(token1).decimals();
        if (_sqrtPriceX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(_sqrtPriceX96) * _sqrtPriceX96;
            price = _asset == token0
                ? FullMath.mulDiv(ratioX192 >> 96, (10 ** decimal0).mul(1e18), 1 << 96).div(10 ** decimal1)
                : FullMath.mulDiv(1 << 192, (10 ** decimal1), ratioX192).mul(1e18).div(10 ** decimal0);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(_sqrtPriceX96, _sqrtPriceX96, 1 << 64);
            price = _asset == token0
                ? FullMath.mulDiv(ratioX128, 10 ** decimal0 * 1e18, (10 ** decimal1) << 128)
                : FullMath.mulDiv(1 << 128, (10 ** decimal1).mul(1e18), ratioX128).div(10 ** decimal0);
        }
    }

    /// @notice Retrieves the latest price data from Chainlink for a given asset
    /// @param _asset The asset address to get the price for
    /// @return price The latest price for the asset from Chainlink
    /// @dev Internal view function, queries the Chainlink aggregator for the asset's latest price
    function getLastedDataFromChainlink(address _asset) internal view returns (uint256 price) {
        AggregatorV3Interface aggregator = AggregatorV3Interface(_assetMap[_asset][1]);
        require(address(aggregator) != address(0), 'Price Feed: invalid aggregator');
        (, int256 newPrice, , uint256 updatedAt, ) = aggregator.latestRoundData();
        require(newPrice > 0 && block.timestamp > updatedAt && updatedAt + _assetTime[_asset] > block.timestamp, 'Price Feed: invalid Oracle');
        uint8 decimals = uint8(AggregatorV3Interface(aggregator).decimals());
        price = mockPrice(uint256(newPrice), decimals);
    }

    /// @notice Public function to get the price for a given asset based on its current pricing plan
    /// @param _asset The asset address to get the price for
    /// @return price The current price for the asset, adhering to the specified price limits
    /// @dev External view function, routes the request to the appropriate pricing plan's logic
    function getPrice(address _asset) external view isSupportedToken(_asset) returns (uint256 price) {
        Plan pl = _plans[_asset];
        if (pl == Plan.CHAINLINK) {
            price = getLastedDataFromChainlink(_asset);
        } else if (pl == Plan.PYTH) {
            price = getPytPrice(_asset);
        } else if (pl == Plan.DEX) {
            price = getPriceFromDex(_asset);
        }
        if (price < _priceLimits[_asset].min || price > _priceLimits[_asset].max) {
            require(false, 'priceLimits error');
        }
    }

    /// @notice Mocks the price conversion to standardize it to 18 decimals
    /// @param originPrice The original price from the price feed
    /// @param decimals The number of decimals the original price uses
    /// @return The standardized price with 18 decimals
    /// @dev Internal pure function, adjusts the price to a common decimal format
    function mockPrice(uint256 originPrice, uint8 decimals) internal pure returns (uint256) {
        return (originPrice * _priceDecimals) / (10 ** decimals);
    }
}
