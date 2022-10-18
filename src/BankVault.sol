/**
 * This is the bank vault for Sugar Dollar (an algorithmic stable coin) treasury
 * More info on https://cryptocookiesdao.com/
 *
 *
 */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BankVault is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable DAI;

    constructor(address _dai) {
        DAI = IERC20(_dai);
    }

    function totalDAI() external view returns (uint256) {
        return DAI.balanceOf(address(this));
    }

    function transferDAI(address account, uint256 amount) external onlyOwner returns (uint256) {
        // Transfer back Collateral Token (DAI) to account
        DAI.safeTransfer(account, amount);
        return amount;
    }
}
