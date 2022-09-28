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

        // SUSD - DAI twap price
        oracleSUSD.mockprice(0.99 ether);
        // CKIE - MATIC twap price
        oracleCKIE.mockprice(0.7 ether);
    }

    function testMultiOracle() public {
        vm.expectRevert("Price <= 0");
        multiOracle.info();
        // real world data
        feedDAI.mockData(36893488147422279069, 99910199, 1664376182, 1664376182, 36893488147422279069);
        feedMATIC.mockData(36893488147422307128, 74462206, 1664376356, 1664376356, 36893488147422307128);

        // SUSD - DAI twap price
        oracleSUSD.mockprice(0.89 ether);
        // CKIE - MATIC twap price
        oracleCKIE.mockprice(0.7 ether);

        assertEq(oracleSUSD.consult(SUSD, 1 ether), 0.89 ether);
        assertEq(multiOracle.daiPrice(), 99910199);
        // susd in usd = 0.88920077 = usdPrice
        uint256 usdPRICE = 0.89 ether * uint256(99910199) / 1 ether;
        assertEq(multiOracle.susdPrice(), usdPRICE);

        usdPRICE = 0.7 ether * uint256(74462206) / 1 ether;
        assertEq(multiOracle.cookiePrice(), usdPRICE);
    }

    function testChainlinkOracle() public {
        vm.expectRevert("Price <= 0");
        multiOracle.daiPrice();

        feedDAI.mockData(0, 1e8, 0, 0, 0);
        vm.expectRevert("Round not complete");
        multiOracle.daiPrice();

        feedDAI.mockData(3, 1e8, 1, 1, 2);
        vm.expectRevert("Stale price");
        multiOracle.daiPrice();

        // real world data
        feedDAI.mockData(36893488147422279069, 99910199, 1664376182, 1664376182, 36893488147422279069);
        assertEq(multiOracle.daiPrice(), 99910199);
    }

    function testMockOracle(uint48 _p) public {
        // price should always be the same for this case
        uint256 p = uint256(_p);

        oracleSUSD.mockprice(p);
        assertEq(oracleSUSD.consult(SUSD, 0.5 ether), p);
        assertEq(oracleSUSD.consult(SUSD, 1 ether), p);
        assertEq(oracleSUSD.consult(SUSD, 2 ether), p);
    }
}
