// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {MultiOracle} from "../src/MultiOracle.sol";

import {ChainlinkMock} from "../src/mocks/ChainlinkMock.sol";
import {OracleMock} from "../src/mocks/OracleMock.sol";

import {CollateralPolicy} from "../src/CollateralPolicy.sol";

contract BasicTokenTest is Test {
    MultiOracle public multiOracle;

    OracleMock public oracleCKIE;
    OracleMock public oracleSUSD;

    ChainlinkMock public feedDAI;
    ChainlinkMock public feedMATIC;

    CollateralPolicy public collateralPolicy;

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

        // SUSD - DAI twap price
        oracleSUSD.mockprice(0.99 ether);

        // chainlink data
        feedDAI.mockData(36893488147422279069, 99910199, 1664376182, 1664376182, 36893488147422279069);
        collateralPolicy = new CollateralPolicy(address(multiOracle));
    }

    function testLimitBand() public {
        feedDAI.mockData(36893488147422279069, 1e8, 1664376182, 1664376182, 36893488147422279069);
        oracleSUSD.mockprice(1.005 ether);
        assertEq(multiOracle.susdPrice(), 1e8 + 50_0000);
        skip(600);
        uint256 target = collateralPolicy.updateAndGet();
        assertEq(target, 1e8);

        oracleSUSD.mockprice(1.00501 ether);
        skip(600);
        target = collateralPolicy.updateAndGet();
        // 99.75%
        assertEq(target, 99_75_0000);

        oracleSUSD.mockprice(0.995 ether);
        skip(600);
        target = collateralPolicy.updateAndGet();
        // 99.75%
        assertEq(target, 99_75_0000);

        oracleSUSD.mockprice(0.99499999 ether);
        skip(600);
        target = collateralPolicy.updateAndGet();
        // 100%
        assertEq(target, 1e8);
    }

    function testMaxTarget1e8() public {
        uint256 target = collateralPolicy.updateAndGet();
        assertEq(target, 1e8);

        skip(600);

        // price shouldnt move if is between upper and bottom band
        target = collateralPolicy.updateAndGet();
        assertEq(target, 1e8);

        // time havent pass, shoulnd change collateral policy
        oracleSUSD.mockprice(2 ether);
        assertEq(target, 1e8);
    }

    function testDownUpTarget() public {
        // sUSD > 1 USD, target collateral should decay
        oracleSUSD.mockprice(2 ether);
        skip(600);
        uint256 target = collateralPolicy.updateAndGet();
        // 99.75 %
        assertEq(target, 99_75_0000);
        skip(1200);
        target = collateralPolicy.updateAndGet();
        // 99.75 %
        assertEq(target, 99_50_0000);

        uint256 newTarget = 99_50_0000;
        for (uint256 i = 0; i < 99; i++) {
            assertEq(target, newTarget);
            skip(600);
            target = collateralPolicy.updateAndGet();
            // 0.25%
            newTarget -= 25_0000;
        }

        // shouldnt go lower
        assertEq(target, 75_00_0000);
        skip(600);
        target = collateralPolicy.updateAndGet();
        assertEq(target, 75_00_0000);
        newTarget = 75_00_0000;

        oracleSUSD.mockprice(0.8 ether);
        // lets go up
        for (uint256 i = 0; i < 99; i++) {
            assertEq(target, newTarget);
            skip(600);
            target = collateralPolicy.updateAndGet();
            // 0.25%
            newTarget += 25_0000;
        }
    }
}
