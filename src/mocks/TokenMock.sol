/**
 * This is a rewards token for the game CryptoCookie
 * You cant play at https://cryptocookiesdao.com/
 *
 *
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Token for mock porpouses
 */
contract TokenMock is ERC20, ERC20Burnable, Ownable {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function burn(uint256 amount) public override {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) public override {
        _burn(account, amount);
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
