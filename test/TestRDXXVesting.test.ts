import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { RDXX, UniswapV2FactoryMock, MockERC20, UniswapV2RouterMock } from "../typechain-types"; // Ajuste o caminho conforme necessário

describe("RDXX Token Vesting", function () {
  let rdxx: RDXX;
  let usdc: MockERC20;
  let factory: UniswapV2FactoryMock;
  let router: UniswapV2RouterMock;
  let owner: Signer;
  let beneficiary: Signer;
  let addr1: Signer;
  let ownerAddress: string;
  let beneficiaryAddress: string;
  const totalTokens: number = 20 * 10 ** 6; // 1000 tokens, considerando 6 casas decimais
  const totalAmountVested: number = 80 * 10 ** 6; // 100 tokens vestidos
  const percentPerInterval: number = 25; // 20%
  const intervals: number = 4; // 4 intervalos

  beforeEach(async function () {
    [owner, beneficiary, addr1] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    beneficiaryAddress = await beneficiary.getAddress();

    const MockERC20 = await ethers.getContractFactory("MockERC20");

    usdc = await MockERC20.deploy("MockToken", "MTK") as MockERC20;
    await usdc.waitForDeployment();

    const UniswapV2FactoryMock = await ethers.getContractFactory("UniswapV2FactoryMock");
    factory = (await UniswapV2FactoryMock.deploy()) as UniswapV2FactoryMock;

    const UniswapV2RouterMock = await ethers.getContractFactory("UniswapV2RouterMock");
    router = (await UniswapV2RouterMock.deploy(await usdc.getAddress(), await usdc.getAddress(), await factory.getAddress(), await owner.getAddress())) as UniswapV2RouterMock;


    const RDXXFactory = await ethers.getContractFactory("RDXX");
    rdxx = (await RDXXFactory.deploy(await usdc.getAddress(), await beneficiary.getAddress(), await beneficiary.getAddress(), await router.getAddress())) as RDXX;
    await rdxx.waitForDeployment();

    // Transferência de tokens para o beneficiário (simulando aquisição antes do vesting)
    await rdxx.transfer(beneficiaryAddress, totalTokens);
    await rdxx.transfer(addr1, totalTokens);
  });

  it("deve bloquear tokens e liberá-los conforme o cronograma de vesting", async function () {
    // Configuração do vesting
    await rdxx.setupVesting(beneficiaryAddress, totalAmountVested, percentPerInterval, intervals);

    // Simula o passar do tempo e verifica a liberação dos tokens em cada intervalo
    for (let i = 0; i < intervals; i++) {
      // Aumenta o tempo para o próximo intervalo
      await ethers.provider.send("evm_increaseTime", [5 * 60]); // 5 minutos em segundos
      await ethers.provider.send("evm_mine", []);

      const elapsedTime = (i + 1) * 5; // tempo em minutos

      // Calcula a quantidade esperada de tokens liberados até o momento atual
      const expectedReleased = Math.floor((totalAmountVested * percentPerInterval / 100) * (i + 1));
      //console.log(`Tokens esperados liberados: ${expectedReleased / 10 ** 6}`);

      // Verifica se a quantidade de tokens transferida corresponde à expectativa
      const tx = await rdxx.connect(beneficiary).transfer(ownerAddress, 19 * 10 ** 6);
      await tx.wait();

      //console.log(`Saldo do beneficiário 1: ${await rdxx.balanceOf(beneficiaryAddress)} tokens`);

      const beneficiaryBalance = await rdxx.balanceOf(beneficiaryAddress);
      const numericBeneficiaryBalance = Number(beneficiaryBalance.toString());
      //console.log(`Saldo do beneficiário 2: ${numericBeneficiaryBalance / 10 ** 6} tokens`);

      // Verificações finais para cada intervalo podem ser adicionadas aqui
    }
  });

  it("erro de transferencia com trade desabilitado", async function () {
    await expect(rdxx.connect(addr1).transfer(await beneficiary.getAddress(), 10 * 10 ** 6)).to.be.revertedWith('Trading disabled');
  });

  it("transferencia entre usuarios", async function () {
    await rdxx.connect(owner).enableTrading();
    await rdxx.connect(addr1).transfer(await beneficiary.getAddress(), 10 * 10 ** 6)
  });
});
