pragma solidity ^0.8.0;

interface ICollateralPolicy {
    function updateAndGet() external returns (uint256);
}
