// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UniswapV2FactoryMock.sol";

contract UniswapV2RouterMock is Ownable {
    IERC20 public token1;
    IERC20 public token2;
    UniswapV2FactoryMock private factoryMock;
    uint256 public constant PRICE_FIXED = 0.04 ether; // Representa o preço fixo de 1 token1 em termos de token2

    constructor(
        address _token1,
        address _token2,
        address _factory,
        address _owner
    ) Ownable(_owner) {
        token1 = IERC20(_token1);
        token2 = IERC20(_token2);

        factoryMock = UniswapV2FactoryMock(_factory);
    }

    function factory() public view returns (address){
        return address(factoryMock);
    }

    function addLiquidity (uint256 _token1Amount, uint256 _token2Amount) external {
        // Transfere os montantes especificados dos tokens do deployer para o contrato
        require(
            token1.transferFrom(msg.sender, address(this), _token1Amount),
            "UniswapV2RouterMock: Transfer of token1 failed"
        );
        require(
            token2.transferFrom(msg.sender, address(this), _token2Amount),
            "UniswapV2RouterMock: Transfer of token2 failed"
        );
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external {
        require(path.length == 2, "UniswapV2RouterMock: INVALID_PATH_LENGTH");
        require(amountIn > 0, "UniswapV2RouterMock: INVALID_INPUT_AMOUNT");
        require(path[0] == address(token1) || path[0] == address(token2), "UniswapV2RouterMock: INVALID_PATH");

        uint256 amountOut;
        IERC20 inputToken = IERC20(path[0]);
        IERC20 outputToken = IERC20(path[1]);
        
        // Verifica se o path[0] é o token1, então calcula o amountOut usando o preço fixo
        if (address(inputToken) == address(token1)) {
            amountOut = amountIn * PRICE_FIXED / 1 ether;
        } else {
            // Se o path[0] é o token2, inverte o preço para a conversão de token2 para token1
            amountOut = amountIn * 1 ether / PRICE_FIXED;
        }

        require(amountOut >= amountOutMin, "UniswapV2RouterMock: INSUFFICIENT_OUTPUT_AMOUNT");
        require(inputToken.balanceOf(msg.sender) >= amountIn, "UniswapV2RouterMock: INSUFFICIENT_INPUT_TOKEN_BALANCE");
        require(inputToken.allowance(msg.sender, address(this)) >= amountIn, "UniswapV2RouterMock: INSUFFICIENT_ALLOWANCE");

        // Realiza a transferência dos tokens
        require(inputToken.transferFrom(msg.sender, address(this), amountIn), "UniswapV2RouterMock: TRANSFER_FROM_FAILED");
        require(outputToken.transfer(to, amountOut), "UniswapV2RouterMock: TRANSFER_FAILED");
    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint256[] memory amounts) {
        uint256[] memory mockedAmounts = new uint256[](2);
        mockedAmounts[0] = amountIn; // Quantidade de tokens que o usuário forneceu
        mockedAmounts[1] = 4 * 10**18; // Mock de 2 ETH retornados, ajuste conforme necessário

        // Para simular o envio de ETH para o endereço `to`, você pode usar o `call`.
        // Lembre-se de que isto é apenas uma simulação. Em um ambiente de produção,
        // a lógica de swap real faria o envio.
        (bool sent, ) = to.call{value: mockedAmounts[1]}("");
        require(sent, "Failed to send Ether");

        return mockedAmounts;
    }

    function WETH() public view returns (address) {
        return address(token2);
    }

    receive() external payable {}
}
