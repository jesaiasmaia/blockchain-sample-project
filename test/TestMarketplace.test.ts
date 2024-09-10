import { ethers } from "hardhat";
import { expect } from "chai";
import { Marketplace, MockERC20 } from "../typechain-types/contracts";
import { Signer } from "ethers";

describe("Marketplace", function () {
    let token: MockERC20;
    let marketplace: Marketplace;
    let owner: Signer;
    let addr1: Signer;
    let addr2: Signer;
    let addr3: Signer;
    let addrs: Signer[];

    beforeEach(async function () {
        // Configuração antes de cada teste
        const Marketplace = await ethers.getContractFactory("Marketplace");
        [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

        // Deploy do token mock ERC20
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        token = await MockERC20.deploy("MockToken", "MTK") as MockERC20;
        await token.waitForDeployment();

        [addr1, ...addrs] = await ethers.getSigners();
        await token.mint(await addr1.getAddress(), ethers.parseEther("2000"));

        await token.transfer(await addr1.getAddress(), ethers.parseEther("100"))
        await token.transfer(await addr2.getAddress(), ethers.parseEther("100"))

        // Substitua "TokenAddress" pelo endereço do seu token RDXX para os testes
        marketplace = await Marketplace.deploy(token.getAddress(), await addr3.getAddress(), "");
    });

    describe("Inclusão de itens", function () {
        it("Deve permitir a inclusão de um novo item e verificar os valores", async function () {            
            // Verificar saldo antes da operação
            //const balanceBefore = await token.balanceOf(await addr1.getAddress());
            //console.log("Saldo antes da operação1: ", balanceBefore.toString());

            // Aprovação
            //await token.connect(addr1).approve(await marketplace.getAddress(), ethers.parseEther("100"));

            // Verificar allowance (permissão) antes da listagem
            //const allowance = await token.allowance(await addr1.getAddress(), await marketplace.getAddress());
            //console.log("Permissão para o contrato Marketplace gastar: ", allowance.toString());

            const listItemTx = await marketplace.connect(addr1).listItem("uuid1", ethers.parseEther("100"));
            await listItemTx.wait();

            const item = await marketplace.items("uuid1");
            expect(item.seller).to.equal(await addr1.getAddress());
            expect(item.price).to.equal(ethers.parseEther("100"));



            // // addr1 lista um item no marketplace
            // await expect(marketplace.connect(addr1).listItem("uuid1", ethers.parseEther("100")))
            //     .to.emit(marketplace, "ItemListed")
            //     .withArgs(await addr1.getAddress(), "uuid1", ethers.parseEther("100"));

            // // Verifique se os valores do item listado estão corretos
            // const item = await marketplace.items("uuid1");
            // expect(item.seller).to.equal(await addr1.getAddress());
            // expect(item.price).to.equal(ethers.parseEther("100"));
        });

        it("Deve falhar ao tentar incluir um item com UUID duplicado", async function () {
            //await token.connect(addr1).approve(await marketplace.getAddress(), ethers.parseEther("100"));

            await marketplace.connect(addr1).listItem("uuid1", ethers.parseEther("100"));

            await expect(marketplace.connect(addr1).listItem("uuid1", ethers.parseEther("200"))).to.be.revertedWith("Item already listed");
        });
    });

    describe("Remoção de itens", function () {
        it("Deve permitir a remoção de um item", async function () {
            //await token.connect(addr1).approve(await marketplace.getAddress(), ethers.parseEther("100"));
            await marketplace.connect(addr1).listItem("uuid2", ethers.parseEther("100"));
            await marketplace.connect(addr1).removeItem("uuid2");

            // Verificar se o item foi removido
            const item = await marketplace.items("uuid2");
            expect(item.seller).to.equal(ethers.ZeroAddress);
        });

        it("Deve falhar ao tentar remover um item que não existe", async function () {
            await expect(marketplace.connect(addr1).removeItem("uuid3")).to.be.revertedWith("Not the seller");
        });
    });

    describe("Compra de itens", function () {
        it("Deve permitir a compra de um item e verificar os saldos", async function () {
            await marketplace.connect(addr1).listItem("uuid2", ethers.parseEther("100"));

            const balanceBefore = await token.balanceOf(await addr2.getAddress());

            await token.connect(addr2).approve(await marketplace.getAddress(), ethers.parseEther("100"));
            await marketplace.connect(addr2).buyItem("uuid2");
            
            const item = await marketplace.items("uuid2");
            expect(item.seller).to.equal(ethers.ZeroAddress);

            expect(await token.balanceOf(await addr2.getAddress())).to.eq(balanceBefore - ethers.parseEther("100"));
            expect(await token.balanceOf(await addr3.getAddress())).to.eq(ethers.parseEther("4"));
        });

        it("Deve falhar ao tentar comprar um item listado pelo próprio comprador", async function () {
            await token.connect(addr1).approve(await marketplace.getAddress(), ethers.parseEther("100"));

            await marketplace.connect(addr1).listItem("uuid4", ethers.parseEther("100"));
            await expect(marketplace.connect(addr1).buyItem("uuid4")).to.be.revertedWith("Seller cannot buy their own item");
        });
    });
});
