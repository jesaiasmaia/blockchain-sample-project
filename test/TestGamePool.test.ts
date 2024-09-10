import { ethers } from "hardhat";
import { expect } from "chai";
import { MockERC20, UniswapV2RouterMock, UniswapV2FactoryMock } from "../typechain-types/contracts";
import { GamePoolContract } from "../typechain-types/contracts/GamePool.sol";
import { Signer } from "ethers";

describe("Game Pool", function () {
    let RDXX: MockERC20;
    let usdc: MockERC20;
    let wbnb: MockERC20;
    let factory: UniswapV2FactoryMock;
    let gamePoolSol: GamePoolContract;
    let usdcRDXXPair: UniswapV2RouterMock;
    let usdcBNBPair: UniswapV2RouterMock;
    let owner: Signer;
    let addr1: Signer;
    let addr2: Signer;
    let addrs: Signer[];

    beforeEach(async function () {
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

        const GamePoolContract = await ethers.getContractFactory("GamePoolContract");
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        const UniswapV2RouterMock = await ethers.getContractFactory("UniswapV2RouterMock");

        const UniswapV2FactoryMock = await ethers.getContractFactory("UniswapV2FactoryMock");
        factory = (await UniswapV2FactoryMock.deploy()) as UniswapV2FactoryMock;

        RDXX = await MockERC20.deploy("MockToken", "MTK") as MockERC20;
        await RDXX.waitForDeployment();

        await RDXX.mint(await addr1.getAddress(), ethers.parseEther("100000"));

        usdc = await MockERC20.deploy("MockUSDC", "USDC") as MockERC20;
        await usdc.waitForDeployment();

        await usdc.mint(await addr1.getAddress(), ethers.parseEther("100000"));

        wbnb = await MockERC20.deploy("MockWBNB", "WBNB") as MockERC20;
        await wbnb.waitForDeployment();

        await wbnb.mint(await addr1.getAddress(), ethers.parseEther("100000"));

        usdcRDXXPair = await UniswapV2RouterMock.deploy(await RDXX.getAddress(), await usdc.getAddress(), await factory.getAddress(), await addr1.getAddress()) as UniswapV2RouterMock;
        await usdcRDXXPair.waitForDeployment();

        usdcBNBPair = await UniswapV2RouterMock.deploy(await wbnb.getAddress(), await usdc.getAddress(), await factory.getAddress(), await addr1.getAddress()) as UniswapV2RouterMock;
        await usdcBNBPair.waitForDeployment();

        gamePoolSol = await GamePoolContract.deploy(await usdc.getAddress(), await RDXX.getAddress(), await usdcRDXXPair.getAddress(), await usdcBNBPair.getAddress(), await addr1.getAddress());

        /* TRANSFER TO RDXX PAIR */
        await RDXX.connect(addr1).approve(await usdcRDXXPair.getAddress(), ethers.parseEther("25000"));
        await usdc.connect(addr1).approve(await usdcRDXXPair.getAddress(), ethers.parseEther("1000"));

        await RDXX.connect(addr1).transfer(await usdcRDXXPair.getAddress(), ethers.parseEther("25000"))
        await usdc.connect(addr1).transfer(await usdcRDXXPair.getAddress(), ethers.parseEther("1000"))

        
        /* TRANSFER TO BNB PAIR */
        await wbnb.connect(addr1).approve(await usdcBNBPair.getAddress(), ethers.parseEther("25000"));
        await usdc.connect(addr1).approve(await usdcBNBPair.getAddress(), ethers.parseEther("1000"));

        await wbnb.connect(addr1).transfer(await usdcBNBPair.getAddress(), ethers.parseEther("25000"))
        await usdc.connect(addr1).transfer(await usdcBNBPair.getAddress(), ethers.parseEther("1000"))

        await addr1.sendTransaction({
            to: await usdcBNBPair.getAddress(),
            value: ethers.parseEther("10") // Envia 10 Ether, ajuste conforme necessário
        });

        await usdc.connect(addr1).approve(await gamePoolSol.getAddress(), ethers.parseEther("500"));
        await usdc.connect(addr1).transfer(await gamePoolSol.getAddress(), ethers.parseEther("500"))
    });

    it("withdrawUsdc should swap and transfer funds correctly", async function () {
        await gamePoolSol.connect(addr1).setAuthorized(await addr1.getAddress());
        
        await gamePoolSol.connect(addr1).withdrawUsdc(await addr2.getAddress(), ethers.parseEther("10"));
    });

    it("withdrawToken should swap and transfer funds correctly", async function () {
        await gamePoolSol.connect(addr1).setAuthorized(await addr1.getAddress());

        await gamePoolSol.connect(addr1).withdrawToken(await addr2.getAddress(), ethers.parseEther("10"));

        expect(await RDXX.balanceOf(await addr2.getAddress())).to.equal(ethers.parseEther("190"));

    });
});
