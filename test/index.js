const { ethers, deployments, upgrades } = require("hardhat");
const { expect } = require("chai");

// describe("NFTAuction", async function() {
//    it("should create an auction", async function() {
//      const NFTAuction = await ethers.getContractFactory("NFTAuction")
//      const nftAuction = await NFTAuction.deploy()
//      await nftAuction.waitForDeployment()

//      await nftAuction.createAuction(
//         100*1000,
//         ethers.parseEther("0.001"),
//         ethers.ZeroAddress,
//         1
//     )

//      const auction = await nftAuction.auctions(0)
//      console.log(auction);
//    })
// })

describe("Test upgrade", async function () {
  it("should upgrade the contract", async function () {
    //1 部署业务合约
    await deployments.fixture(["deployNftAuction"]);

    const nftAuctionProxy = await deployments.get("NftAuctionProxy");

    //2 调用createAuction方法创建拍卖

    // 读取代理合约的业务合约实例
    const nftAuction = await ethers.getContractAt(
      "NftAuction",
      nftAuctionProxy.address
    );

    const auction = await nftAuction.auctions(0);
    console.log("当前拍卖信息 :", auction);

    const implementationAddress1 = await upgrades.erc1967.getImplementationAddress(
      nftAuctionProxy.address
    );

    //3 升级合约
    await deployments.fixture(["upgradeNftAuction"]);

    // 获取升级后的实现合约地址
    const implementationAddress2 =
      await upgrades.erc1967.getImplementationAddress(nftAuctionProxy.address);
    //  console.log("当前实现合约地址 :", implementationAddress2);

    //4 读取合约的 auction(0)
    const auction2 = await nftAuction.auctions(0);
    console.log("升级后的拍卖信息 :", auction2);

    // 读取升级后的业务合约实例
    const nftAuctionV2 = await ethers.getContractAt(
      "NftAuctionV2",
      nftAuctionProxy.address
    );

    // 调用testHello方法
     const hello = await nftAuctionV2.testHello() 
     console.log("hello :", hello);

    // 检查升级后的合约版本
    expect(auction2.startTime).to.equal(auction.startTime);
    expect(implementationAddress2).to.not.equal(implementationAddress1);
  });
});
