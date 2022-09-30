// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {CollateralPolicy} from "../src/CollateralPolicy.sol";

contract MultiOracleDeployScript is Script {
    function setUp() public {}

    function run() public {
        address multiOracle = 0xD13cCE7F76318eDC9584A6b1c9729776bA67fD84;

        vm.startBroadcast();
        new CollateralPolicy(address(multiOracle));
        vm.stopBroadcast();
    }
}
