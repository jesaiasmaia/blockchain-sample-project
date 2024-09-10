import { ethers } from "hardhat";
import { expect } from "chai";
import { MockERC20, UniswapV2RouterMock, UniswapV2FactoryMock } from "../typechain-types/contracts";
import { ArdoxusPurchaseContract } from "../typechain-types/contracts/ArdoxusPurchases.sol";
import { Signer } from "ethers";

describe("Purchase", function () {
    let usdc: MockERC20;
    let RDXX: MockERC20;
    let factory: UniswapV2FactoryMock;
    let ardoxusPurchase: ArdoxusPurchaseContract;
    let mockSwapRouter: UniswapV2RouterMock;
    let owner: Signer;
    let addr1: Signer;
    let addr2: Signer;
    let addrs: Signer[];

    beforeEach(async function () {
        [owner, addr1] = await ethers.getSigners();
        const ArdoxusPurchase = await ethers.getContractFactory("PurchaseContract");
        const UniswapRouter = await ethers.getContractFactory("UniswapV2RouterMock");

        const MockERC20 = await ethers.getContractFactory("MockERC20");
        usdc = await MockERC20.deploy("USDC", "USDC") as MockERC20;
        await usdc.waitForDeployment();

        const UniswapV2FactoryMock = await ethers.getContractFactory("UniswapV2FactoryMock");
        factory = (await UniswapV2FactoryMock.deploy()) as UniswapV2FactoryMock;
        
        await usdc.mint(await addr1.getAddress(), ethers.parseEther("40000"));

        RDXX = await MockERC20.deploy("RDXX", "RDXX") as MockERC20;
        await RDXX.waitForDeployment();

        await RDXX.mint(await addr1.getAddress(), ethers.parseEther("2000000"));

        mockSwapRouter = await UniswapRouter.deploy(await RDXX.getAddress(), await usdc.getAddress(), await factory.getAddress(), await addr1.getAddress());
        await mockSwapRouter.connect(addr1).waitForDeployment()

        RDXX.connect(addr1).approve(await mockSwapRouter.getAddress(), ethers.parseEther("1000000"))
        usdc.connect(addr1).approve(await mockSwapRouter.getAddress(), ethers.parseEther("40000"))

        mockSwapRouter.connect(addr1).addLiquidity(ethers.parseEther("1000000"), ethers.parseEther("40000"))

        ardoxusPurchase = await ArdoxusPurchase.deploy(await usdc.getAddress(), await RDXX.getAddress(), await mockSwapRouter.getAddress(), await owner.getAddress());
        await ardoxusPurchase.waitForDeployment()

        await ardoxusPurchase.connect(owner).toggleSales()
    });

    describe("Inclusão de itens", function () {
        it("should register a box correctly", async function () {
            const boxId = 1;
            const price = ethers.parseEther("10");
            const supply = 0;
    
            await ardoxusPurchase.connect(owner).registerBox(boxId, price);
    
            const box = await ardoxusPurchase.boxes(boxId);
            expect(box.price).to.equal(price);
            expect(box.supplySold).to.equal(0);
        });
    });

    describe("Purchase Box and Token Swap", function () {
        it("should allow a user to purchase a box and check USDC balance", async function () {
            const boxId = 1;
            const priceInRDXX = ethers.parseEther("10");
            const price = 10;
            const RDXXToUSDCRate = 0.04; // Taxa de conversão de RDXX para USDC
            const expectedUSDC = price * RDXXToUSDCRate;
    
            // Registrando uma caixa para venda
            await ardoxusPurchase.connect(owner).registerBox(boxId, priceInRDXX);
    
            // Aprovando o contrato de compras para gastar RDXX em nome de addr1
            await RDXX.connect(addr1).approve(await ardoxusPurchase.getAddress(), priceInRDXX);
    
            // Quantidade de USDC no contrato antes da compra
            const initialUSDCBalance = Number(ethers.formatEther(await usdc.balanceOf(await ardoxusPurchase.getAddress())));
            const RDXXBalance = Number(ethers.formatEther(await RDXX.balanceOf(await ardoxusPurchase.getAddress())));
    
            // addr1 compra a caixa
            await ardoxusPurchase.connect(addr1).purchaseBox(boxId, 1); // Assume que '1' é a quantidade comprada
    
            // Quantidade de USDC no contrato após a compra
            const finalUSDCBalance = Number(ethers.formatEther(await usdc.balanceOf(await ardoxusPurchase.getAddress())));
    
            // Verifica se o valor esperado de USDC foi recebido pelo contrato
            expect(finalUSDCBalance - initialUSDCBalance).to.equal(expectedUSDC);
            expect(RDXXBalance).to.equal(0);
        });
    });
    
});
