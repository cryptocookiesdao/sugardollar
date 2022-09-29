pragma solidity ^0.8.0;

import {IERC20Burneable} from "../interfaces/IERC20Burneable.sol";

contract GameMock {
    IERC20Burneable public immutable token;

    constructor(address token_) {
        token = IERC20Burneable(token_);
    }

    /// @dev only minter will be able to access this function, this is just a mock and doesnt have that logic
    function sugarBankMint(address _to, uint256 _amount) external {
        token.mint(_to, _amount);
    }
}
