pragma solidity ^0.8.0;

interface IOracle {
    function daiPrice() external returns (uint256);

    /// @notice Returns the price of 1 SUSD based on twap price & chainlink
    /// @return uint256 1 ether SUSD in USD
    function susdPrice() external returns (uint256);

    /// @notice Returns the price of 1 CKIE based on twap price & chainlink
    /// @return uint256 1 ether CKIE in USD
    function cookiePrice() external returns (uint256);
}
