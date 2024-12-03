// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from 'forge-std/Test.sol';
import 'forge-std/console.sol';

import '../contracts/FastPriceFeed.sol';
import '../contracts/interfaces/IUniswapV3Pool.sol';
import '../contracts/interfaces/IUniswapV3SwapRouter.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract FastPriceFeedTestV2 is Test {
    using SafeMath for uint256;

    // FastPriceFeed priceFeed = FastPriceFeed(0x96f7c66Ee5fceA22dfBD1251c064fbe6d5282284);
    FastPriceFeed priceFeed;
    address MAX = 0x9e37523f0304980b6cFADCc7BA15b8ca59e2B717;
    address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address PG = 0x6fD58f5a2F3468e35fEb098b5F59F04157002407;
    address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address owner = 0xCeAF5223a095015cd111655C841bBC3E301B34cd;
    address pyth = 0xff1a0f4744e8582DF1aE09D5611b887B6a12925C;
    string ArbRpc = 'https://arbitrum-mainnet.infura.io/v3/1bafc863dc5f45f7b4712952e1f22e26';

    FastPriceFeed.Plan public plan;

    function setUp() public {
        // vm.createSelectFork(ArbRpc, 190310000);
        vm.createSelectFork(ArbRpc);
        // vm.createSelectFork(ArbRpc,190315507);
        priceFeed = new FastPriceFeed(owner);
    }


    function test_getPrice() public {
        vm.startPrank(owner);
        IUniswapV3Pool pool = IUniswapV3Pool(0x4468D34EC0E213a8A060D6282De6Fd407B7B55b3);

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = MAX;
        limit[0] = IFastPriceFeed.PriceLimit(1, type(uint256).max);

        plan = IFastPriceFeed.Plan.DEX;
        priceFeed.newAsset(MAX, [address(pool),address(0),address(0)], bytes32(0), 5 minutes, plan, 0);
        console.log('newAsset end');
        priceFeed.batchSetAssetPriceLimit(token, limit);
        console.log('batchSetAssetPriceLimit end');
        uint256 priceDex = priceFeed.getPrice(MAX);
        console.log(priceDex);

        vm.stopPrank();
    }

    function testWETH() public {
        vm.startPrank(owner);
        address univ3pool = 0xC6962004f452bE9203591991D15f6b388e09E8D0; //WETH-USDC
        address chainlink = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; //ETH-USD
        
        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = WETH;
        limit[0] = IFastPriceFeed.PriceLimit(2800 * 10 ** 18, 5000 * 10 ** 18);

        plan = IFastPriceFeed.Plan.DEX;
        priceFeed.newAsset(WETH, [univ3pool,chainlink,pyth], bytes32(0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace), 5 minutes, plan, 1 days);
        console.log('newAsset end');
        priceFeed.batchSetAssetPriceLimit(token, limit);
        console.log('batchSetAssetPriceLimit end');
        uint256 priceDex = priceFeed.getPrice(WETH);
        console.log('WETH Uniswap price :', priceDex);

        plan = IFastPriceFeed.Plan.CHAINLINK;
        priceFeed.switchPriceFeed(WETH, plan);
        console.log("switchPriceFeed end");
        uint256 priceCex = priceFeed.getPrice(WETH);
        console.log('WETH Chainlink price :', priceCex);
        

        plan = IFastPriceFeed.Plan.PYTH;
        priceFeed.switchPriceFeed(WETH, plan);
        console.log("switchPriceFeed end");
        uint256 pricePyth = priceFeed.getPrice(WETH);
        console.log('WETH Pyth price :', pricePyth);
        vm.stopPrank();
    }

    function testFailWETH() public {
        vm.startPrank(owner);
        address univ3pool = 0xC6962004f452bE9203591991D15f6b388e09E8D0; //WETH-USDC
        address chainlink = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; //ETH-USD
        
        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = WETH;
        limit[0] = IFastPriceFeed.PriceLimit(2800 * 10 ** 18, 5000 * 10 ** 18);

        plan = IFastPriceFeed.Plan.CHAINLINK;
        priceFeed.newAsset(WETH, [address(0),chainlink,address(0)], bytes32(0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace), 5 minutes, plan, 10);
        console.log('newAsset end');
        priceFeed.batchSetAssetPriceLimit(token, limit);
        console.log('batchSetAssetPriceLimit end');
        uint256 priceDex = priceFeed.getPrice(WETH);
        console.log('WETH Chainlink price :', priceDex);
        
        vm.stopPrank();
    }

    function testWBTC() public {
        vm.startPrank(owner);
        address univ3pool = 0xA62aD78825E3a55A77823F00Fe0050F567c1e4EE; //WBTC-USDC
        address chainlink = 0x6ce185860a4963106506C203335A2910413708e9; 
        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = WBTC;
        limit[0] = IFastPriceFeed.PriceLimit(60000 * 10 ** 18, 80000 * 10 ** 18);

        plan = IFastPriceFeed.Plan.DEX;
        priceFeed.newAsset(WBTC, [univ3pool,chainlink,pyth], bytes32(0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43), 5 minutes, plan, 1 days);
        console.log('newAsset end');
        priceFeed.batchSetAssetPriceLimit(token, limit);
        console.log('batchSetAssetPriceLimit end');
        uint256 priceDex = priceFeed.getPrice(WBTC);
        console.log('WBTC Uniswap price :', priceDex);

        plan = IFastPriceFeed.Plan.CHAINLINK;
        priceFeed.switchPriceFeed(WBTC, plan);
        console.log("switchPriceFeed end");
        uint256 priceCex = priceFeed.getPrice(WBTC);
        console.log('BTC Chainlink price :', priceCex);
        

        plan = IFastPriceFeed.Plan.PYTH;
        priceFeed.switchPriceFeed(WBTC, plan);
        console.log("switchPriceFeed end");
        uint256 pricePyth = priceFeed.getPrice(WBTC);
        console.log('BTC Pyth price :', pricePyth);
        
        vm.stopPrank();
    }

    function testFailPG() public {
        vm.startPrank(owner);
        address univ3pool = 0x8da66e470403b3d3eEE66c67E2C61fda6E248Ad1; //PG-USDC
        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = PG;
        limit[0] = IFastPriceFeed.PriceLimit(5 *10**13, 1 *10**14);

        plan = IFastPriceFeed.Plan.DEX;
        priceFeed.newAsset(PG, [univ3pool,address(0),address(0)], bytes32(0), 5 minutes, plan, 0);
        console.log('newAsset end');
        priceFeed.batchSetAssetPriceLimit(token, limit);
        console.log('batchSetAssetPriceLimit end');
        uint256 priceDex = priceFeed.getPrice(PG);
        console.log('PG Uniswap price :', priceDex);

        plan = IFastPriceFeed.Plan.CHAINLINK;
        priceFeed.switchPriceFeed(PG, plan);
        console.log("switchPriceFeed fail");
        vm.stopPrank();
    }

    function testMax1() public {
        vm.startPrank(owner);
        address univ3pool = 0x7f580f8A02b759C350E6b8340e7c2d4b8162b6a9;
        deal(USDT, owner, 1e56);

        IUniV3SwapRouter router = IUniV3SwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        IUniV3SwapRouter.ExactInputSingleParams memory para = IUniV3SwapRouter.ExactInputSingleParams(
            USDT,
            DAI,
            uint24(100),
            owner,
            block.timestamp,
            1e56,
            1,
            0
        );
        IERC20(USDT).approve(address(router), type(uint256).max);
        router.exactInputSingle(para);
        vm.warp(block.timestamp + 1 days);

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = DAI;
        limit[0] = IFastPriceFeed.PriceLimit(1, type(uint256).max);

        plan = IFastPriceFeed.Plan.DEX;
        priceFeed.newAsset(DAI, [univ3pool,address(0),address(0)], bytes32(0), 5 minutes, plan, 0);
        console.log('newAsset end');
        priceFeed.batchSetAssetPriceLimit(token, limit);
        console.log('batchSetAssetPriceLimit end');
        uint256 priceDex = priceFeed.getPrice(DAI);
        console.log('DAI Uniswap price :', priceDex);

        vm.stopPrank();
    }

    function testMax2() public {
        vm.startPrank(owner);
        address univ3pool = 0x7f580f8A02b759C350E6b8340e7c2d4b8162b6a9;
        deal(DAI, owner, 1e56);

        IUniV3SwapRouter router = IUniV3SwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        IUniV3SwapRouter.ExactInputSingleParams memory para = IUniV3SwapRouter.ExactInputSingleParams(
            DAI,
            USDT,
            uint24(100),
            owner,
            block.timestamp,
            1e56,
            1,
            0
        );
        IERC20(DAI).approve(address(router), type(uint256).max);
        router.exactInputSingle(para);
        vm.warp(block.timestamp + 1 days);

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = USDT;
        limit[0] = IFastPriceFeed.PriceLimit(1, type(uint256).max);

        plan = IFastPriceFeed.Plan.DEX;
        priceFeed.newAsset(USDT, [univ3pool,address(0),address(0)], bytes32(0), 5 minutes, plan, 0);
        console.log('newAsset end');
        priceFeed.batchSetAssetPriceLimit(token, limit);
        console.log('batchSetAssetPriceLimit end');
        uint256 priceDex = priceFeed.getPrice(USDT);
        console.log('USDT Uniswap price :', priceDex);
        
        vm.stopPrank();
    }

    function testMin1() public {
        vm.startPrank(owner);
        address univ3pool = 0x7f580f8A02b759C350E6b8340e7c2d4b8162b6a9;
        deal(USDT, owner, 1e56);

        IUniV3SwapRouter router = IUniV3SwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        IUniV3SwapRouter.ExactInputSingleParams memory para = IUniV3SwapRouter.ExactInputSingleParams(
            USDT,
            DAI,
            uint24(100),
            owner,
            block.timestamp,
            5e16,
            1,
            0
        );
        IERC20(USDT).approve(address(router), type(uint256).max);
        router.exactInputSingle(para);
        vm.warp(block.timestamp + 1 days);

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = USDT;
        limit[0] = IFastPriceFeed.PriceLimit(1, type(uint256).max);

        plan = IFastPriceFeed.Plan.DEX;
        priceFeed.newAsset(USDT, [univ3pool,address(0),address(0)], bytes32(0), 5 minutes, plan, 0);
        console.log('newAsset end');
        priceFeed.batchSetAssetPriceLimit(token, limit);
        console.log('batchSetAssetPriceLimit end');
        uint256 priceDex = priceFeed.getPrice(USDT);
        console.log('USDT Uniswap price :', priceDex);

        vm.stopPrank();
    }

    function testMin2() public {
        vm.startPrank(owner);
        address univ3pool = 0x7f580f8A02b759C350E6b8340e7c2d4b8162b6a9;
        deal(DAI, owner, 1e56);

        IUniV3SwapRouter router = IUniV3SwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        IUniV3SwapRouter.ExactInputSingleParams memory para = IUniV3SwapRouter.ExactInputSingleParams(
            DAI,
            USDT,
            uint24(100),
            owner,
            block.timestamp,
            1e28,
            1,
            0
        );
        IERC20(DAI).approve(address(router), type(uint256).max);
        router.exactInputSingle(para);
        vm.warp(block.timestamp + 1 days);

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = DAI;
        limit[0] = IFastPriceFeed.PriceLimit(1, type(uint256).max);

        plan = IFastPriceFeed.Plan.DEX;
        priceFeed.newAsset(DAI, [univ3pool,address(0),address(0)], bytes32(0), 5 minutes, plan, 0);
        console.log('newAsset end');
        priceFeed.batchSetAssetPriceLimit(token, limit);
        console.log('batchSetAssetPriceLimit end');
        uint256 priceDex = priceFeed.getPrice(DAI);
        console.log('DAI Uniswap price :', priceDex);

        vm.stopPrank();
    }
}
