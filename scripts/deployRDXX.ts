import { ethers } from "hardhat";

async function main() {
  const usdtToken = "";
  //const owner = "";
  const founders = "";
  const router = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
  const reward = "";
  
  //constructor(address _usdt, address _development, address _reward, address _router)

  const Ardoxus = await ethers.getContractFactory("Ardoxus");
  const ardoxus = await Ardoxus.deploy(usdtToken, founders, reward, router, {
    maxPriorityFeePerGas: ethers.parseUnits('3', 'gwei'), // Ajuste este valor
    maxFeePerGas: ethers.parseUnits('5', 'gwei'),
  });

  await ardoxus.waitForDeployment();

  console.log("Marketplace deployed to:", await ardoxus.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
