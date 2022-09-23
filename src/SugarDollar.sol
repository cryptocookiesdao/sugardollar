/**
 * The Sugar Dollar an algorithmic stable coin
 * More info on https://cryptocookiesdao.com/
 *
 **/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * After deploying this contract, ownership will be transfer to the game, and
 * only the game will mint tokens to give players rewards
 */
contract SugarDollar is ERC20, ERC20Burnable, Ownable {
    constructor(uint256 _initialSupply) ERC20("SugarDollar", "sUSD") {
        _mint(msg.sender, _initialSupply);
    }

    // the SugarBank can mint tokens based on the minting policy
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }
}
