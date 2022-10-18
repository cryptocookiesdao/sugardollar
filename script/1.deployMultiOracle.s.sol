// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {MultiOracle} from "../src/MultiOracle.sol";

contract MultiOracleDeployScript is Script {
    function setUp() public {}

    function run() public {
        // 10 minutes TWAP oracle
        address oracleCKIE = 0x527Ae6049BDF594f45893df13cdD057A85E809F0;
        // 10 minutes TWAP oracle
        address oracleSUSD = 0x1a8a1DbD56D2b2A06309D519d242153c749caF58;

        address feedDAI = 0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D;
        address feedMATIC = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;

        address CKIE = 0x3C0Bd2118a5E61C41d2aDeEBCb8B7567FDE1cBaF;
        address SUSD = 0x43b59BfF4F01729836a35Ce6425b196370Bb41a3;

        vm.startBroadcast();
        address multiOracle = address(new MultiOracle(oracleCKIE, oracleSUSD, feedDAI, feedMATIC, CKIE, SUSD));
        vm.stopBroadcast();

        console.log("Multioracle Address", multiOracle);
    }
}
