// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {MultiOracle} from "../src/MultiOracle.sol";

import {ChainlinkMock} from "../src/mocks/ChainlinkMock.sol";
import {OracleMock} from "../src/mocks/OracleMock.sol";

contract BasicTokenTest is Test {
    MultiOracle public multiOracle;

    OracleMock public oracleCKIE;
    OracleMock public oracleSUSD;

    ChainlinkMock public feedDAI;
    ChainlinkMock public feedMATIC;

    address CKIE;
    address SUSD;

    function setUp() public {
        SUSD = makeAddr("SUSD");
        CKIE = makeAddr("CKIE");

        feedMATIC = new ChainlinkMock();
        feedDAI = new ChainlinkMock();

        oracleCKIE = new OracleMock();
        oracleSUSD = new OracleMock();

        multiOracle = new MultiOracle(
            address(oracleCKIE), address(oracleSUSD),
            address(feedDAI), address(feedMATIC),
            address(CKIE), address(SUSD)
        );
    }

    function testOracle() public {
        // TODO
        assertTrue(true);
    }
}
