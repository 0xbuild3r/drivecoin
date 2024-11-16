const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DriveCoin System", function () {
  let driveCoin, coinManager, stakingPool;
  let owner, government, carOwner, user;
  let bitkubVar;

  beforeEach(async function () {
    // Get signers
    [owner, government, carOwner, user] = await ethers.getSigners();

    // Deploy DriveCoin contract
    const DriveCoin = await ethers.getContractFactory("DriveCoin");
    driveCoin = await DriveCoin.deploy();
    await driveCoin.deployed();

    // Deploy CoinManager contract with government as the designated address
    const CoinManager = await ethers.getContractFactory("CoinManager");
    coinManager = await CoinManager.deploy(driveCoin.address, government.address);
    await coinManager.deployed();

    // Retrieve the StakingPool contract deployed by CoinManager
    stakingPool = await ethers.getContractAt("StakingPool", await coinManager.stakingPool());

    // Transfer some tokens to carOwner and user for staking and testing
    await driveCoin.transfer(carOwner.address, ethers.utils.parseEther("1000"));
    await driveCoin.transfer(user.address, ethers.utils.parseEther("1000"));

    // Approve StakingPool contract to spend carOwner's tokens
    await driveCoin.connect(carOwner).approve(stakingPool.address, ethers.utils.parseEther("1000"));

    // Set Bitkub Next ID variables
    bitkubVar = 7216;
  });

  it("should allow car owner to stake tokens", async function () {
    await stakingPool.connect(carOwner).stake(ethers.utils.parseEther("100"));

    expect(await stakingPool.stakes(carOwner.address)).to.equal(ethers.utils.parseEther("100"));
  });

  it("should allow government to reward a staked car owner", async function () {
    // First, stake some tokens
    await stakingPool.connect(carOwner).stake(ethers.utils.parseEther("100"));

    // Reward the car owner through CoinManager
    await coinManager.connect(government).rewardCar(carOwner.address, ethers.utils.parseEther("10"));

    expect(await driveCoin.balanceOf(carOwner.address)).to.equal(ethers.utils.parseEther("910")); // initial - stake + reward
    expect(await stakingPool.rewards(carOwner.address)).to.equal(ethers.utils.parseEther("10"));
  });

  it("should allow government to burn tokens from a staked car owner", async function () {
    // First, stake some tokens
    await stakingPool.connect(carOwner).stake(ethers.utils.parseEther("100"));

    // Burn a portion of the staked tokens
    await coinManager.connect(government).burnFromStake(carOwner.address, ethers.utils.parseEther("50"));

    expect(await stakingPool.stakes(carOwner.address)).to.equal(ethers.utils.parseEther("50"));
  });

  it("should allow government to reward a public transport user at peak time", async function () {
    await coinManager.connect(government).rewardUser(user.address, ethers.utils.parseEther("20"));

    expect(await driveCoin.balanceOf(user.address)).to.equal(ethers.utils.parseEther("1020")); // initial + reward
  });

  it("should only allow government to perform restricted actions", async function () {
    // Try to reward a car owner by a non-government account
    await stakingPool.connect(carOwner).stake(ethers.utils.parseEther("100"));
    await expect(
      coinManager.connect(user).rewardCar(carOwner.address, ethers.utils.parseEther("10"))
    ).to.be.revertedWith("Only government can call this function");

    // Try to burn from a stake by a non-government account
    await expect(
      coinManager.connect(user).burnFromStake(carOwner.address, ethers.utils.parseEther("50"))
    ).to.be.revertedWith("Only government can call this function");

    // Try to reward a user by a non-government account
    await expect(
      coinManager.connect(user).rewardUser(user.address, ethers.utils.parseEther("20"))
    ).to.be.revertedWith("Only government can call this function");
  });
});
