// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockUniswapV2Pair {
    address public tokenA;
    address public tokenB;

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    // Adicione qualquer função do par que seu contrato principal chama
    function getReserves() external pure returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        return (0, 0, 0); // Retorna valores dummy
    }
}
