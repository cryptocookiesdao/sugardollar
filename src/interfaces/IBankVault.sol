pragma solidity ^0.8.0;

interface IBankVault {
    function totalUSDC() external view returns (uint256);

    function transferUSDC(address account, uint256 amount) external returns (uint256);
}
