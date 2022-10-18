// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {SugarBank} from "../src/SugarBank.sol";
import {BankVault} from "../src/BankVault.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IGame} from "src/interfaces/IGame.sol";

contract LocalDeployScript is Script {
    address constant feedDAI = 0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D;
    address constant feedMATIC = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;

    address constant CKIE = 0x3C0Bd2118a5E61C41d2aDeEBCb8B7567FDE1cBaF;
    address constant SUSD = 0x43b59BfF4F01729836a35Ce6425b196370Bb41a3;
    address constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

    address constant GAME = 0x14dB5c0C433a05CAEb78DD7515CbAf67aa772d77;
    address constant uniswapV2Router = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;

    address constant multiOracle = 0x6939305B3fd05Dca6Af79fdED8958faC9DB47308;
    address constant collateralPolicy = 0x1C214645062f4E7542f8a44641eEe3c600F6dD50;

    address constant treasury = 0x33dD9953496Ed0a6092C49Ad7b2d408042FF1d21;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        SugarBank sugarBank = new SugarBank(
            // quicktime router
            uniswapV2Router,
            SUSD,
            CKIE,
            DAI,
            // game,
            GAME,
            treasury,
            multiOracle,
            collateralPolicy
        );

        BankVault(treasury).setOwner(address(sugarBank));
        Ownable(SUSD).transferOwnership(address(sugarBank));
        // allow bank to mint cookies
        IGame(GAME).setSugarBankMinter(address(sugarBank));
        vm.stopBroadcast();

        console.log("SugarBank:", address(sugarBank));
        console.log("treasury:", address(treasury));
        console.log("Multioracle:", address(multiOracle));
        console.log("collateralPolicy:", address(collateralPolicy));
    }
}
