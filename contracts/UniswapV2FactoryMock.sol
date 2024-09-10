// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./UniswapV2PairMock.sol";

contract UniswapV2FactoryMock {
    address public lastPair;

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        MockUniswapV2Pair newPair = new MockUniswapV2Pair(tokenA, tokenB);
        lastPair = address(newPair);
        return lastPair;
    }
}