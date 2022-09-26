// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IOracleSimple} from "./interfaces/IOracleSimple.sol";
import {IChainlinkFeed} from "./interfaces/IChainlinkFeed.sol";

// TODO MULTI ORACLE
//   CALC CKIE TO MATIC TO USD USING CHAINLINK FEED 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
//   CALC DAI TO USD USING CAHINLINK FEED 0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D

contract MultiOracle {
    IOracleSimple immutable twapOracleCKIE;
    IOracleSimple immutable twapOracleSUSD;

    IChainlinkFeed immutable feedDAIUSD;
    IChainlinkFeed immutable feedMATICUSD;

    address immutable CKIE;
    address immutable SUSD;

    constructor(
        address _oracleCKIE,
        address _oracleSUSD,
        address _feedDAI,
        address _feedMATIC,
        address _CKIE,
        address _SUSD
    ) {
        twapOracleCKIE = IOracleSimple(_oracleCKIE);
        twapOracleSUSD = IOracleSimple(_oracleSUSD);
        feedDAIUSD = IChainlinkFeed(_feedDAI);
        feedMATICUSD = IChainlinkFeed(_feedMATIC);
        CKIE = _CKIE;
        SUSD = _SUSD;
    }

    /// @notice This is the price of 1 DAI in USD, base 1e8
    /// @return uint256 DAI price in USD, base 1e8
    function daiPrice() public view returns (uint256) {
        (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answeredInRound) = feedDAIUSD.latestRoundData();
        require(price > 0, "Price <= 0");
        require(answeredInRound >= roundId, "Stale price");
        require(updatedAt > 0, "Round not complete");

        return uint256(price);
    }

    /// @notice This is the price of 1 MATIC in USD, base 1e8
    /// @return uint256 MATIC price in USD, base 1e8
    function maticPrice() public view returns (uint256) {
        (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answeredInRound) = feedMATICUSD.latestRoundData();
        require(price > 0, "Price <= 0");
        require(answeredInRound >= roundId, "Stale price");
        require(updatedAt > 0, "Round not complete");

        return uint256(price);
    }

    /// @notice This is the price of 1 CKIE in USD, base 1e8
    /// @return uint256 CKIE price in USD, base 1e8
    function cookiePrice() public returns (uint256) {
        // update oracle twap observation
        twapOracleCKIE.update();

        // compute CKIE price
        return (twapOracleCKIE.consult(CKIE, 1 ether) * maticPrice()) / 1 ether;
    }

    /// @notice This is the price of 1 SUSD in USD, base 1e8
    /// @return uint256 SUSD price in USD, base 1e8
    function susdPrice() public returns (uint256) {
        // update oracle twap observation
        twapOracleSUSD.update();

        // compute CKIE price
        return (twapOracleCKIE.consult(SUSD, 1 ether) * daiPrice()) / 1 ether;
    }

    /// @dev this is not safe for computations because oracles could be stale, this function its only menat to use in front end
    function info() external view returns (uint256 daiprice, uint256 cookieUSD, uint256 susdUSD) {
        daiprice = daiPrice();

        // load price from Oracle
        cookieUSD = (twapOracleCKIE.consult(CKIE, 1 ether) * uint256(maticPrice())) / 1 ether;

        susdUSD = (twapOracleSUSD.consult(SUSD, 1 ether) * uint256(daiprice)) / 1e6;
    }
}
