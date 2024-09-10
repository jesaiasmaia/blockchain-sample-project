import { ethers } from "hardhat";

async function main() {
  const _USDTTOKENADDRESS = "";
  const _FOUNDERS = "";
  const _FOUNDERSWITHRESTORE = "";
  const _INITIALOWNER = "";

  // Deploy do contrato Marketplace
  const FusionNFT = await ethers.getContractFactory("FusionNft");
  const fusionNFT = await FusionNFT.deploy(
    _USDTTOKENADDRESS,
    _FOUNDERS,
    _FOUNDERSWITHRESTORE,
    _INITIALOWNER,
    {
      maxPriorityFeePerGas: ethers.parseUnits("3", "gwei"), // Ajuste este valor
      maxFeePerGas: ethers.parseUnits("5", "gwei"),
    }
  );

  await fusionNFT.waitForDeployment();

  console.log("FusionNFT deployed to:", await fusionNFT.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
