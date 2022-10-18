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

    IERC20 public immutable DAI;

    constructor(address _dai) {
        DAI = IERC20(_dai);
    }

    function totalDAI() external view returns (uint256) {
        return DAI.balanceOf(address(this));
    }

    // Transfer back Collateral Token (DAI) to account        
    function transferDAI(address account, uint256 amount) external onlyOwner returns (uint256) {
        /// @dev by definition DAI will always work or revert, thats thy i dont use a SafeTransferLib.
        /// @dev please see https://github.com/makerdao/dss/blob/master/src/dai.sol#L89
        DAI.transfer(account, amount);
        return amount;
    }
}
