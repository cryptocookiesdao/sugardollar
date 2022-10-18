// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {BankVault} from "../src/BankVault.sol";

contract MultiOracleDeployScript is Script {
    function setUp() public {}

    function run() public {
        address DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        vm.startBroadcast();
        address bankVault = address(new BankVault(DAI));
        vm.stopBroadcast();

        console.log("bankVault", bankVault);
    }
}
