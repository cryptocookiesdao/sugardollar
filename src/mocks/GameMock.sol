pragma solidity ^0.8.0;

import {ISugarDollar} from "../interfaces/ISugarDollar.sol";

contract GameMock {
    ISugarDollar public immutable token;

    constructor(address token_) {
        token = ISugarDollar(token_);
    }

    /// @dev only minter will be able to access this function, this is just a mock and doesnt have that logic
    function sugarBankMint(address _to, uint256 _amount) external {
        token.mint(_to, _amount);
    }
}
