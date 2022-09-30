pragma solidity ^0.8.0;

interface IGame {
    function sugarBankMint(address _to, uint256 _amount) external;

    // this func is onlyOwner
    function setSugarBankMinter(address _sugarBankMinter) external;
}
