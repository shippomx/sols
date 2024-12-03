pragma solidity ^0.8.12;
import "forge-std/Test.sol";
// import 'forge-std/StdCheats.sol';
import "forge-std/console.sol";
// import "../src/interfaces/IUniswapV3SwapRouter.sol";
import "../contracts/Aggregator.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import '../src/uniswapV3/libraries/LiquidityAmounts.sol';
// import '../src/uniswapV3/libraries/TickMath.sol';
// import "../contracts/test/UniswapRouterV2V3.sol";
contract AggregatorTest is Test {
    address MAX = 0x9e37523f0304980b6cFADCc7BA15b8ca59e2B717;
    address ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;
    address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address USDCE = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address owner = makeAddr("owner");
    address v3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address v2Router = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    string ArbRpc = "https://arbitrum-mainnet.infura.io/v3/1bafc863dc5f45f7b4712952e1f22e26";
    Aggregator aggregator;
    function setUp()public{
        vm.startPrank(owner);
        vm.createSelectFork(ArbRpc, 215579886);
        deal(USDT,owner,100000 * 10**6);
        deal(ARB,owner,100000 ether);
        deal(USDCE,owner,100000 ether);
        address[] memory cfg = new address[](2);
        cfg[0] = v3Router;
        cfg[1] = v2Router;
        aggregator = new Aggregator(cfg,owner);
        addStrategy();
        vm.stopPrank();
    }

    function addStrategy()public{
        Aggregator.UniV3Data[] memory data = new Aggregator.UniV3Data[](1);
        Aggregator.UniV2Data[] memory data2 = new Aggregator.UniV2Data[](1);
        //USDT-ARB
        data[0].path = abi.encodePacked(USDT,uint24(500),ARB);
        data[0].ratio = 6000;
        data[0].index = 0;
        aggregator.updateUniV3Strategy(USDT, ARB, data);

        data2[0].path = new address[](2);
        data2[0].path[0] = USDT;
        data2[0].path[1] = ARB;
        data2[0].ratio = 4000;
        data2[0].index= 1;
        aggregator.updateUniV2Strategy(USDT, ARB, data2);
        //ARB-USDT
        data[0].path = abi.encodePacked(USDT,uint24(500),ARB);
        data[0].ratio = 5000;
        data[0].index = 0;
        aggregator.updateUniV3Strategy(ARB, USDT, data);

        data2[0].path = new address[](2);
        data2[0].path[0] = ARB;
        data2[0].path[1] = USDT;
        data2[0].ratio = 5000;
        data2[0].index= 1;
        aggregator.updateUniV2Strategy(ARB, USDT, data2);

        //USDC.e-WETH
        data[0].path = abi.encodePacked(WETH,uint24(500),USDCE);
        data[0].ratio = 4356;
        data[0].index = 0;
        aggregator.updateUniV3Strategy(USDCE, WETH, data);

        data2[0].path = new address[](2);
        data2[0].path[0] = USDCE;
        data2[0].path[1] = WETH;
        data2[0].ratio = 5644;
        data2[0].index= 1;
        aggregator.updateUniV2Strategy(USDCE, WETH, data2);
        //WETH-USDC.e
        data[0].path = abi.encodePacked(WETH,uint24(500),USDCE);
        data[0].ratio = 5747;
        data[0].index = 0;
        aggregator.updateUniV3Strategy(WETH,USDCE, data);

        data2[0].path = new address[](2);
        data2[0].path[0] = WETH;
        data2[0].path[1] = USDCE;
        data2[0].ratio = 4253;
        data2[0].index= 1;
        aggregator.updateUniV2Strategy(WETH,USDCE, data2);
        console.log("updateStrategy end");
    }

    function testSwapIn()public{
        vm.startPrank(owner);
        console.log("begin to exactInput");
        IERC20(USDT).approve(address(aggregator),30 *10**6);
        uint256 outAmount = aggregator.exactInput(USDT,30*10**6,ARB,15 ether);
        assertGt(outAmount, 20 ether);
        console.log("ARB output Amount:",outAmount);
        console.log("end exactInput");
        vm.stopPrank();
    }

    function testSwapOut()public{
        vm.startPrank(owner);
        console.log("begin to exactOutput");
        IERC20(ARB).approve(address(aggregator),30 ether);
        uint256 inAmount = aggregator.exactOutput(ARB,30 ether,USDT,20 *10**6);
        assertLt(inAmount, 20 ether);
        console.log("ARB input Amount",inAmount);
        console.log("end exactOutput");
        vm.stopPrank();
    }

    function testSwapOutDecimal()public{
        vm.startPrank(owner);
        console.log("begin to exactOutput");
        IERC20(USDCE).approve(address(aggregator),3000*10**6);
        uint256 inAmount = aggregator.exactOutput(USDCE,3000*10**6,WETH,646876478645645687);
        assertEq(IERC20(WETH).balanceOf(owner),646876478645645687);
        console.log("USDCE input Amount",inAmount);
        console.log("end exactOutput");
        vm.stopPrank();
    }

    function testSwapInDecimal()public{
        testSwapOutDecimal();
        vm.startPrank(owner);
        console.log("begin to exactOutput");
        IERC20(WETH).approve(address(aggregator),646876478645645687);
        uint256 outAmount = aggregator.exactInput(WETH,646876478645645687,USDCE,2000*10**6);
        assertGt(IERC20(USDCE).balanceOf(owner),2000*10**6);
        console.log("WETH output Amount",outAmount);
        console.log("end exactOutput");
        vm.stopPrank();
    }
}
