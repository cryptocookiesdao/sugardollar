// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {MultiOracle} from "../src/MultiOracle.sol";
import {CollateralPolicy} from "../src/CollateralPolicy.sol";
import {SugarBank} from "../src/SugarBank.sol";
import {BankVault} from "../src/BankVault.sol";
import {IOwnable} from "src/interfaces/IOwnable.sol";
import {IGame} from "src/interfaces/IGame.sol";

contract LocalDeployScript is Script {

    address constant feedDAI = 0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D;
    address constant feedMATIC = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;

    address constant CKIE = 0x3C0Bd2118a5E61C41d2aDeEBCb8B7567FDE1cBaF;
    address constant SUSD = 0x43b59BfF4F01729836a35Ce6425b196370Bb41a3;
    address constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address constant weth = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    address constant GAME = 0x14dB5c0C433a05CAEb78DD7515CbAf67aa772d77;
    address constant uniswapV2Router = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    address constant uniswapV2Factory = 0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32;


    address constant oracleCKIE = 0x527Ae6049BDF594f45893df13cdD057A85E809F0;
    address constant oracleSUSD = 0x1a8a1DbD56D2b2A06309D519d242153c749caF58;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        
        address multiOracle = address(new MultiOracle(oracleCKIE, oracleSUSD, feedDAI, feedMATIC, CKIE, SUSD));

        address collateralPolicy = address(new CollateralPolicy(address(multiOracle)));

        BankVault treasury = new BankVault(DAI);

        SugarBank sugarBank = new SugarBank(
            // quicktime router
            uniswapV2Router,
            SUSD,
            CKIE,
            DAI,
            // game,
            GAME,
            address(treasury),
            address(multiOracle),
            address(collateralPolicy)
        );

        treasury.transferOwnership(address(sugarBank));
        IOwnable(SUSD).transferOwnership(address(sugarBank));
        // allow bank to mint cookies
        IGame(GAME).setSugarBankMinter(address(sugarBank));
        vm.stopBroadcast();
        

        console.log("SugarBank:", address(sugarBank));
        console.log("treasury:", address(treasury));
        console.log("Multioracle:", address(multiOracle));
        console.log("collateralPolicy:", address(collateralPolicy));
    }
}
