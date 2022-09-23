pragma solidity ^0.8.0;

interface IOracle {
    function USDCPrice() external returns (uint256);

    function sugarDollarPrice() external returns (uint256);

    function cookieUSDPrice() external returns (uint256);
}
