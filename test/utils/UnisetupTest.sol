// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import {IERC20Burneable} from "../../src/interfaces/IERC20Burneable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TokenMock} from "src/mocks/TokenMock.sol";

import {WETH} from "solmate/tokens/WETH.sol";

import {ZuniswapV2Factory} from "../../src/mocks/uniswap/src/ZuniswapV2Factory.sol";
import {ZuniswapV2Router} from "../../src/mocks/uniswap/src/ZuniswapV2Router.sol";
import {ZuniswapV2Pair} from "../../src/mocks/uniswap/src/ZuniswapV2Pair.sol";

abstract contract UnisetupTest is Test {
    address uniswapV2Factory;
    address uniswapV2Router;

    address immutable weth;
    address immutable DAI;
    address immutable CKIE;
    address immutable SUSD;

    constructor() {
        weth = address(new WETH());
        //address wethAddrInMainnet = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        // vm.etch(wethAddrInMainnet, _weth.code);
        // weth = wethAddrInMainnet;

        CKIE = address(new TokenMock("Cookie", "CKIE"));
        // vm.etch(0x3C0Bd2118a5E61C41d2aDeEBCb8B7567FDE1cBaF, CKIE.code);
        // CKIE = 0x3C0Bd2118a5E61C41d2aDeEBCb8B7567FDE1cBaF;

        DAI = address(new TokenMock("(PoS) Dai Stablecoin", "DAI"));
        // vm.etch(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, DAI.code);
        // DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

        SUSD = address(new TokenMock("SugarDollar", "SUSD"));
        // vm.etch(0x43b59BfF4F01729836a35Ce6425b196370Bb41a3, SUSD.code);
        // SUSD = 0x43b59BfF4F01729836a35Ce6425b196370Bb41a3;

        vm.label(weth, "WETH");
        vm.label(SUSD, "SUSD");
        vm.label(DAI, "DAI");
        vm.label(CKIE, "CKIE");
    }

    function deployFactory() private {
        require(weth != address(0), "weth not initialized");

        uniswapV2Factory = address(new ZuniswapV2Factory());
        //uniswapV2Factory = deployCode("UniswapV2Factory.sol:UniswapV2Factory", abi.encode(address(0)));
        // vm.etch(0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32, uniswapV2Factory.code);
        // uniswapV2Factory = 0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32;
        uniswapV2Router = address(new ZuniswapV2Router(uniswapV2Factory, weth));
        /*
    uniswapV2Router = deployCode(
                "UniswapV2Router02.sol:UniswapV2Router02",
                abi.encode(uniswapV2Factory, weth)
        );
        */
        // vm.etch(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff, uniswapV2Router.code);
        // uniswapV2Router = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    }

    function createPairs() public {
        IERC20(CKIE).approve(uniswapV2Router, type(uint256).max);
        IERC20(weth).approve(uniswapV2Router, type(uint256).max);
        IERC20(DAI).approve(uniswapV2Router, type(uint256).max);
        IERC20(SUSD).approve(uniswapV2Router, type(uint256).max);

        weth.call{value: 10369.58540543 ether}("");
        IERC20Burneable(CKIE).mint(address(this), 12325.40694347 ether);

        IUniswapV2Router02(uniswapV2Router).addLiquidity(
            weth,
            CKIE,
            10369.58540543 ether,
            12325.40694347 ether,
            10369.58540543 ether,
            12325.40694347 ether,
            address(this),
            block.timestamp + 60
        );

        IERC20Burneable(DAI).mint(address(this), 111551 ether);
        weth.call{value: 145978 ether}("");
        IUniswapV2Router02(uniswapV2Router).addLiquidity(
            weth, DAI, 145978 ether, 111551 ether, 145978 ether, 111551 ether, address(this), block.timestamp + 60
        );

        IERC20Burneable(DAI).mint(address(this), 90.34462773 ether);
        IERC20Burneable(SUSD).mint(address(this), 100.72127317 ether);

        IUniswapV2Router02(uniswapV2Router).addLiquidity(
            DAI,
            SUSD,
            90.34462773 ether,
            100.72127317 ether,
            9.34462773 ether,
            10.72127317 ether,
            address(this),
            block.timestamp + 60
        );

        IERC20Burneable(CKIE).mint(address(this), 105.06838632 ether);
        IERC20Burneable(SUSD).mint(address(this), 75.66848 ether);

        IUniswapV2Router02(uniswapV2Router).addLiquidity(
            CKIE, SUSD, 105.06838632 ether, 75.66848 ether, 105.06838632 ether, 75.66848 ether, address(this), block.timestamp + 60
        );

        // 0x71acf87C1F35fC1E3ec7C8A8dA302724Bdf768b4, 0x18669eb6c7dFc21dCdb787fEb4B3F1eBb3172400, 0xc21b423350BCe22097957A043068D15E62eb33DC
    }

    function setUp() public virtual {
        // deploy WETH, CKIE, DAI, SUSD
        deployFactory();

        createPairs();
    }
}
