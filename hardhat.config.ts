import "@nomicfoundation/hardhat-verify";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

require("dotenv").config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      evmVersion: "shanghai",
    },
  },
  networks: {
    bscTestnet: {
      url: process.env.BSC_URL,
      accounts: [process.env.PRIVATE_KEY!],
    },
    bsc: {
      url: process.env.BSC_URL_MAINNET,
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
  etherscan: {
    apiKey: {
      bscTestnet: process.env.API_BSC_SCAN!,
      bsc: process.env.API_BSC_SCAN!,
    },
  },
  sourcify: {
    enabled: false,
  },
};

export default config;
