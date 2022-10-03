pragma solidity ^0.8.0;

interface IOwnable {
    function transferOwnership(address s) external;
    function owner() external view returns (address);
}
