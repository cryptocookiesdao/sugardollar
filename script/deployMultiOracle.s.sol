// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {MultiOracle} from "../src/MultiOracle.sol";

contract MultiOracleDeployScript is Script {
    function setUp() public {}

    function run() public {
        // 10 minutes TWAP oracle
        address oracleCKIE = 0xE42d5A242bDcc9E116894fCC8aD67e253574068E;
        // 10 minutes TWAP oracle
        address oracleSUSD = 0x81372682B25823211d822E1C174e04493246Bb2d;

        address feedDAI = 0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D;
        address feedMATIC = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;

        address CKIE = 0x3C0Bd2118a5E61C41d2aDeEBCb8B7567FDE1cBaF;
        address SUSD = 0x43b59BfF4F01729836a35Ce6425b196370Bb41a3;

        vm.startBroadcast();
        new MultiOracle(oracleCKIE, oracleSUSD, feedDAI, feedMATIC, CKIE, SUSD);
        vm.stopBroadcast();
    }
}
