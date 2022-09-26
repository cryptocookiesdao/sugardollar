pragma solidity ^0.8.0;

contract OracleMock {
    uint256 price;

    constructor() {}

    function mockprice(uint256 _price) external {
        price = _price;
    }

    function update() external {}

    function consult(address, uint256 amountIn) external view returns (uint256 amountOut) {
        // 1 ether == 18 decimals
        return price * amountIn / 1 ether;
    }
}
