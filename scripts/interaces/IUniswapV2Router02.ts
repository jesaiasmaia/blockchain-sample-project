import { BigNumberish } from "ethers";
import { ContractTransaction } from "ethers";

export interface IUniswapV2Router02 {
  swapExactTokensForTokens(
    amountIn: BigNumberish,
    amountOutMin: BigNumberish,
    path: string[],
    to: string,
    deadline: number,
  ): Promise<ContractTransaction>;
}