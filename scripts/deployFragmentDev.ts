import { ethers } from "hardhat";

async function main() {
  const usdtToken = "";
  
  //constructor(address _usdt, address _development, address _reward, address _router)

  const RDXX = await ethers.getContractFactory("FragmentPurchase");
  const RDXX = await RDXX.deploy(usdtToken);

  await ardoxus.waitForDeployment();

  console.log("Marketplace deployed to:", await ardoxus.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
