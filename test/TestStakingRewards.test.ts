import { ethers } from "hardhat";
import { expect } from "chai";
import {
  MockERC20,
  StakingRewards,
  MockUSDC,
} from "../typechain-types/contracts";
import { Signer } from "ethers";

describe("Staking Rewards", function () {
  let RDXX: MockERC20;
  let usdc: MockUSDC;

  let stakingRewards: StakingRewards;

  let owner: Signer;
  let addr1: Signer;

  let addrs: Signer[];

  beforeEach(async function () {
    [owner, addr1, ...addrs] = await ethers.getSigners();

    const StakingRewardsContract = await ethers.getContractFactory(
      "StakingRewards"
    );
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const MockUSDC = await ethers.getContractFactory("MockUSDC");

    RDXX = (await MockERC20.deploy("MockToken", "MTK")) as MockERC20;
    await RDXX.waitForDeployment();

    await RDXX.mint(await addr1.getAddress(), ethers.parseUnits("100000", 6));

    usdc = (await MockUSDC.deploy("MockUSDC", "USDC")) as MockUSDC;
    await usdc.waitForDeployment();

    await usdc.mint(await owner.getAddress(), ethers.parseEther("100000"));

    stakingRewards = await StakingRewardsContract.deploy(
      await RDXX.getAddress(),
      await usdc.getAddress(),
      await owner.getAddress()
    );

    await stakingRewards.connect(owner).setStakeAreEnabled();
    await stakingRewards.connect(owner).setRewardsDuration(5184000);

    const isStakedisabled = await stakingRewards.stakeEnabled();
    expect(isStakedisabled).to.be.true;

    await stakingRewards
      .connect(owner)
      .notifyRewardAmount(ethers.parseEther("10000"));

    await usdc
      .connect(owner)
      .transfer(await stakingRewards.getAddress(), ethers.parseEther("10000"));

    await RDXX
      .connect(addr1)
      .approve(await stakingRewards.getAddress(), ethers.parseUnits("1000", 6));
    await stakingRewards.connect(addr1).stake(ethers.parseUnits("1000", 6));
  });

  it("Should revert stake after one day", async function () {
    await ethers.provider.send("evm_increaseTime", [86401]);
    await ethers.provider.send("evm_mine");
    await RDXX
      .connect(addr1)
      .approve(await stakingRewards.getAddress(), ethers.parseUnits("1000", 6));
    await expect(
      stakingRewards.connect(addr1).stake(ethers.parseUnits("1000", 6))
    ).to.be.reverted;
  });

  it("Should get rewards after stake duration", async function () {
    await expect(stakingRewards.connect(addr1).getReward()).to.be.reverted;
  });

  it("Should revert stake when staking is disabled", async function () {
    await stakingRewards.connect(owner).setStakeAreEnabled();
    const isStakeEnabled = await stakingRewards.stakeEnabled();
    expect(isStakeEnabled).to.be.false;

    await RDXX
      .connect(addr1)
      .approve(await stakingRewards.getAddress(), ethers.parseUnits("1000", 6));
    await expect(
      stakingRewards.connect(addr1).stake(ethers.parseUnits("1000", 6))
    ).to.be.reverted;
  });

  it("Should be able to claim rewards", async function () {
    const balanceUSDCBefore = await stakingRewards
      .connect(addr1)
      .rewards(addr1);
    expect(balanceUSDCBefore).to.not.equal(0);
    await ethers.provider.send("evm_increaseTime", [5184001]);
    await ethers.provider.send("evm_mine", []);
    await expect(stakingRewards.connect(addr1).getReward()).to.not.be.reverted;
    const balanceUSDC = await stakingRewards.connect(addr1).rewards(addr1);
    await expect(balanceUSDC).to.equal(0);
  });

  it("Should withdraw rewards after reward duration finished", async function () {
    await ethers.provider.send("evm_increaseTime", [5184001]);
    await ethers.provider.send("evm_mine", []);
    const userBalanceBefore = await stakingRewards.balanceOf(
      await addr1.getAddress()
    );
    expect(userBalanceBefore).to.not.equal(0);
    await expect(stakingRewards.connect(addr1).withdraw()).to.emit(
      stakingRewards,
      "Withdrawn"
    );
    const userBalance = await stakingRewards.balanceOf(
      await addr1.getAddress()
    );
    expect(userBalance).to.equal(0);
  });
});
