// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {CollateralPolicy} from "../src/CollateralPolicy.sol";

contract MultiOracleDeployScript is Script {
    function setUp() public {}

    function run() public {
        address multiOracle = 0x6939305B3fd05Dca6Af79fdED8958faC9DB47308;

        vm.startBroadcast();
        address collateralPolicy = address(new CollateralPolicy(multiOracle));
        vm.stopBroadcast();

        console.log("collateralPolicy", collateralPolicy);
    }
}
