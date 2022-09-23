// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {SugarDollar} from "../src/SugarDollar.sol";
import {GameMock} from "../src/mocks/GameMock.sol";

contract BasicTokenTest is Test {
    SugarDollar public token;
    GameMock public game;
    address deployer;

    function setUp() public {
        deployer = makeAddr("deployer");
        vm.prank(deployer);
        token = new SugarDollar(10 ether);
        game = new GameMock(address(token));
    }

    function testSupplyAndBurn() public {
        assertEq(token.totalSupply(), 10 ether);
        // token creator owns initial supply
        assertEq(token.totalSupply(), 10 ether);

        vm.prank(deployer);
        token.burn(5 ether);

        assertEq(token.totalSupply(), 5 ether);

        vm.expectRevert("ERC20: insufficient allowance");
        token.burnFrom(deployer, 5 ether);
        assertEq(token.totalSupply(), 5 ether);
    }

    function testGameMint() public {
        vm.expectRevert("Ownable: caller is not the owner");
        game.sugarBankMint(vm.addr(31337), 10 ether);

        vm.prank(deployer);
        token.transferOwnership(address(game));
        game.sugarBankMint(vm.addr(31337), 10 ether);

        assertEq(token.balanceOf(vm.addr(31337)), 10 ether);

        assertEq(token.totalSupply(), 20 ether);
    }
}
