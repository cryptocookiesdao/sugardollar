pragma solidity ^0.8.0;

interface IBankVault {
    function totalDAI() external view returns (uint256);

    function transferDAI(address account, uint256 amount) external returns (uint256);
}
