const { ethers, upgrades } = require("hardhat");
const path = require("path");
const fs = require("fs");

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { save } = deployments;
  const { deployer } = await getNamedAccounts();
  console.log("部署用户地址 :", deployer);

  //读取 .cache/proxyNftAuction.json
  const storagePath = path.resolve(__dirname, "./.cache/proxyNftAuction.json");
  const storageData = fs.readFileSync(storagePath, "utf-8");
  const { proxyAddress, implementationAddress, abi } = JSON.parse(storageData);
  console.log("代理合约地址 :", proxyAddress);

  //升级版的代理合约
  const nftAuctionV2 = await ethers.getContractFactory("NftAuctionV2");

  //升级代理合约
  const nftAuctionProxyV2= await upgrades.upgradeProxy(
    proxyAddress,
    nftAuctionV2,
    { call: "admin" }
  );
  await nftAuctionProxyV2.waitForDeployment();
  const proxyAddressV2 = await nftAuctionProxyV2.getAddress();

//   //保存升级后的合约地址
//   fs.writeFileSync(
//     storagePath,
//     JSON.stringify({
//       proxyAddress: proxyAddressV2,
//       implementationAddress,
//       abi: abi,
//     })
//   );
   await save("NftAuctionProxyV2",{
    abi: abi,
    address: proxyAddressV2,
   })
};

module.exports.tags = ["upgradeNftAuction"];
