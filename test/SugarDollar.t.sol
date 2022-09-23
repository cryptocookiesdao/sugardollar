// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SugarDollar.sol";

contract BasicTokenTest is Test {
    SugarDollar public token;
    address deployer;
    
    function setUp() public {
        deployer = makeAddr("deployer");
        token = new SugarDollar(10 ether);
    }

    function testSupply() public {
        assertEq(token.totalSupply(), 10 ether);
        // token creator owns initial supply
        assertEq(token.totalSupply(), 10 ether);
    }

}
