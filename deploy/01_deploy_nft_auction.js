const { deployments, upgrades, ethers } = require("hardhat");

const fs = require("fs");
const path = require("path");
const { log } = require("console");

// deploy/00_deploy_my_contract.js
module.exports = async ({ getNamedAccounts, deployments }) => {
  const { save } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("部署用户地址: ", deployer);
  const NftAuction = await ethers.getContractFactory("NftAuction");

  // 通过代理部署代理合约
  const nftAuctionProxy = await upgrades.deployProxy(NftAuction, [], {
    initializer: "initialize",
  });

  await nftAuctionProxy.waitForDeployment();

  const proxyAddress = await nftAuctionProxy.getAddress();
  console.log("代理合约地址: ", proxyAddress);
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    proxyAddress
  );
  console.log("实现合约地址: ", implementationAddress);

  // 保存代理合约地址和实现合约地址
  const storagePath = path.resolve(__dirname, "./.cache/proxyNftAuction.json");
  fs.writeFileSync(
    storagePath,
    JSON.stringify({
        proxyAddress,
        implementationAddress,
        abi:NftAuction.interface.format("json")
      })
  );

  await save("NftAuctionProxy",{
     address: proxyAddress,
     abi: NftAuction.interface.format("json")
  });
};

module.exports.tags = ["deployNftAuction"];
