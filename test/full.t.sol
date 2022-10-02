// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {UnisetupTest} from "./utils/UnisetupTest.sol";

import {IERC20, IERC20Burneable} from "src/interfaces/IERC20Burneable.sol";

import {IOracleSimple} from "../src/interfaces/IOracleSimple.sol";
import {IGame} from "../src/interfaces/IGame.sol";

import {CollateralPolicy} from "../src/CollateralPolicy.sol";

import {BankVault} from "../src/BankVault.sol";
import {SugarBank} from "../src/SugarBank.sol";
import {GameMock} from "../src/mocks/GameMock.sol";

import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {MultiOracle} from "../src/MultiOracle.sol";

import {ChainlinkMock} from "../src/mocks/ChainlinkMock.sol";
import {MultiOracle} from "../src/MultiOracle.sol";

contract FullIntegrationTest is UnisetupTest {
    ChainlinkMock feedMATIC;
    ChainlinkMock feedDAI;

    MultiOracle multiOracle;

    CollateralPolicy collateralPolicy;

    BankVault treasury;

    SugarBank sugarBank;

    address DEPLOYER = 0xdA001205EE0E9c0a7a6Cc3FDa137008e7e5bB818;
    address user;

    function setUp() public override {
        super.setUp();

        vm.roll(1);
        user = makeAddr("user");

        address oracleCKIE =
            deployCode("OracleTWAP.sol:TWAPOracleSimple", abi.encode(uniswapV2Factory, weth, CKIE, 60 * 10));
        vm.label(oracleCKIE, "oracle ckie-matic");

        address oracleSUSD =
            deployCode("OracleTWAP.sol:TWAPOracleSimple", abi.encode(uniswapV2Factory, SUSD, DAI, 60 * 10));
        vm.label(oracleSUSD, "oracle susd-dai");

        vm.roll(2);
        // console.log("pair", IUniswapV2Factory(uniswapV2Factory).getPair(CKIE, weth));
        feedMATIC = new ChainlinkMock();
        feedDAI = new ChainlinkMock();
        uint256 DAI_PRICE = 99910199;
        uint256 MATIC_PRICE = 74462206;
        feedDAI.mockData(36893488147422279069, int256(DAI_PRICE), 1664376182, 1664376182, 36893488147422279069);
        feedMATIC.mockData(36893488147422307128, int256(MATIC_PRICE), 1664376356, 1664376356, 36893488147422307128);

        multiOracle = new MultiOracle(
            oracleCKIE, oracleSUSD,
            address(feedDAI), address(feedMATIC),
            CKIE, SUSD
        );

        collateralPolicy = new CollateralPolicy(address(multiOracle));
        vm.label(address(collateralPolicy), "collateralPolicy");

        vm.startPrank(DEPLOYER, DEPLOYER);

        treasury = new BankVault(DAI);

        sugarBank = new SugarBank(
            // quicktime router
            uniswapV2Router,
            SUSD,
            CKIE,
            DAI,
            // game,
            address(new GameMock(CKIE)),
            address(treasury),
            address(multiOracle),
            address(collateralPolicy)
        );

        treasury.transferOwnership(address(sugarBank));

        vm.stopPrank();
        vm.roll(3);
        skip(60 * 10 + 1);
    }

    function testTCR100PercentLimits() public {
        vm.startPrank(user);
        deal(DAI, user, 1000 ether);
        IERC20(DAI).approve(address(sugarBank), 1000 ether);
        vm.expectRevert("Price slippage check");
        sugarBank.mintZap(1000 ether, 900 ether);

        sugarBank.mintZap(500 ether, 497 ether);

        assertEq(IERC20(DAI).balanceOf(user), 500 ether, "Should spend 500 DAI");
        assertEq(treasury.totalDAI(), 500 ether, "Treasury should have 500 DAI");

        // must wait a few blocks for claim
        vm.roll(block.number + 2);
        sugarBank.claim();
        assertApproxEqAbs(
            IERC20(SUSD).balanceOf(user), 498 ether, 0.5 ether, "After two blocks should have around 500 SUSD"
        );

        // ECR (expected collateral ratio = trasuryBalance/susd.totalSupply())
        // lets overcollaterized SUSD
        IERC20Burneable(DAI).mint(address(treasury), 600 ether);
        IERC20(DAI).transfer(address(treasury), IERC20(DAI).balanceOf(user));
        IERC20(SUSD).approve(address(sugarBank), type(uint256).max);
        assertEq(sugarBank.getECR(), sugarBank.BASE(), "ECT Should be 100%");
        IERC20Burneable(SUSD).mint(address(user), 100 ether);
        // mint more than 500 sUSD
        sugarBank.redeem(510 ether);
        assertApproxEqAbs(IERC20(DAI).balanceOf(user), 498.94 ether, 1 ether, "Should have around 500 DAI");
        assertEq(sugarBank.maxBurn(), 0, "Burn limit should be 0");

        skip(10 * 60 + 1);
        assertEq(sugarBank.maxBurn(), 500 ether, "Burn limit should be reset after 10 minutes");

        vm.stopPrank();
        vm.startPrank(address(sugarBank));
        // empty treasury
        treasury.transferDAI(DAI, treasury.totalDAI());
        assertEq(treasury.totalDAI(), 0, "Treasury empty");
        vm.stopPrank();

        vm.startPrank(user);
        // empty user DAI balance
        IERC20(DAI).transfer(DAI, IERC20(DAI).balanceOf(user));
        // empty user CKIE balance
        IERC20(CKIE).transfer(CKIE, IERC20(CKIE).balanceOf(user));
        IERC20Burneable(SUSD).burn(IERC20(SUSD).balanceOf(user));
        IERC20Burneable(SUSD).mint(address(user), 10 ether);
        // for every SugarDollar 0.5 DAI
        IERC20Burneable(DAI).mint(address(treasury), IERC20(SUSD).totalSupply() / 2);
        sugarBank.redeem(10 ether);
        assertApproxEqAbs(sugarBank.getECR(), sugarBank.BASE() / 2, 1e6, "ECR should be aroun 50%");
        assertApproxEqAbs(
            IERC20(DAI).balanceOf(user), 5 ether, 0.5 ether, "Should have around 5 DAI"
        );
        
        assertApproxEqAbs(
            IERC20(CKIE).balanceOf(user) * multiOracle.cookiePrice() / 1e8, 5 ether, 0.5 ether, "Should have around 5 USD in CKIE"
        );

        vm.stopPrank();
    }

    function testTCR100Percent() public {
        vm.startPrank(user);
        deal(DAI, user, 20 ether);
        IERC20(DAI).approve(address(sugarBank), 20 ether);
        sugarBank.mintZap(10 ether, 5 ether);

        assertEq(IERC20(DAI).balanceOf(user), 10 ether, "Should spend 10 DAI");
        assertEq(IERC20(DAI).balanceOf(address(treasury)), 10 ether, "Treasury should have 10 DAI");

        // must wait a few blocks for claim
        assertEq(IERC20(SUSD).balanceOf(user), 0, "Shouldnt have SUSD");
        vm.expectRevert("Wait more blocks");
        sugarBank.claim();

        vm.roll(block.number + 1);
        vm.expectRevert("Wait more blocks");
        sugarBank.claim();

        vm.roll(block.number + 1);
        sugarBank.claim();
        assertApproxEqAbs(
            IERC20(SUSD).balanceOf(user), 9.97 ether, 0.01 ether, "After two blocks should have around 10 SUSD"
        );

        sugarBank.mintZap(5 ether, 4 ether);
        sugarBank.mint(5 ether, 1 ether, 4 ether);
        vm.roll(block.number + 2);
        sugarBank.claim();
        assertApproxEqAbs(IERC20(SUSD).balanceOf(user), 9.97231577116838072 ether * 2, 0.03 ether);

        // only dust in account
        assertApproxEqAbs(IERC20(DAI).balanceOf(user), 0, 0.1 ether);
        assertApproxEqAbs(IERC20(DAI).balanceOf(address(treasury)), 20 ether, 0.1 ether);

        uint256 currentECR = sugarBank.getECR();

        IERC20(SUSD).approve(address(sugarBank), 20 ether);
        sugarBank.redeem(IERC20(SUSD).balanceOf(user));
        assertApproxEqAbs(IERC20(DAI).balanceOf(user), 20 ether * currentECR / sugarBank.BASE(), 0.4 ether);
        

        vm.stopPrank();
    }

    function testTCR75Percent() public {
        vm.mockCall(
            address(collateralPolicy),
            abi.encodeWithSelector(CollateralPolicy.updateAndGet.selector),
            abi.encode(75_00_0000)
        );

        deal(CKIE, user, 10 ether);
        deal(DAI, user, 20 ether);
        // deal(DAI, address(treasury), IERC20(SUSD).totalSupply() / 2);

        vm.startPrank(user);
        IERC20(CKIE).approve(address(sugarBank), 20 ether);
        IERC20(DAI).approve(address(sugarBank), 20 ether);
        sugarBank.mintZap(10 ether, 5 ether);

        // must wait a few blocks for claim
        assertEq(IERC20(SUSD).balanceOf(user), 0);
        vm.expectRevert("Wait more blocks");
        sugarBank.claim();

        sugarBank.mint(7.5 ether, 3 ether, 7 ether);

        assertApproxEqAbs(IERC20(CKIE).balanceOf(user), 7 ether, 1, "Should use 3 cookies");
        assertApproxEqAbs(IERC20(DAI).balanceOf(user), 5.05 ether, 0.1 ether, "Should use around 5 DAI");
        
        vm.stopPrank();
        vm.clearMockedCalls();
    }
}
