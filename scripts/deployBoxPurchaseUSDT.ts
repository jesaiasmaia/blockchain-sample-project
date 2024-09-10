import { ethers } from "hardhat";

async function main() {
  const rdxxTokenAddress = "";
  const owner = "";
  const founders = "";

  // Deploy do contrato Marketplace
  const BoxPurchaseContract = await ethers.getContractFactory("BoxPurchaseContract");
  const marketplace = await BoxPurchaseContract.deploy(rdxxTokenAddress, owner);

  await marketplace.waitForDeployment();

  console.log("Marketplace deployed to:", await marketplace.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
