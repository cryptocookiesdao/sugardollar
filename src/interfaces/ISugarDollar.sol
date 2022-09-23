pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISugarDollar is IERC20 {
    function burn(uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;

    function mint(address account, uint256 amount) external;
}
