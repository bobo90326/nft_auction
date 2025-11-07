// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "./NftAuction.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NftAuctionFactory {
    address[] public auctions;

    mapping (uint256 tokenId => NftAuction) public auctionMap;

    event AuctionCreated(address indexed auctionAddress,uint256 tokenId);

    // Create a new auction
    function createAuction(
        uint256 duration,
        uint256 startPrice,
        address nftContractAddress,
        uint256 tokenId
    ) external returns (address) {
        // 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(new NftAuction()),
            abi.encodeWithSignature(
                "initialize(address,uint256,uint256,address,uint256)",
                msg.sender,
                duration,
                startPrice,
                nftContractAddress,
                tokenId
            )
        );
        NftAuction auction = NftAuction(address(proxy));
         
        auctions.push(address(auction));// 记录状态后，再调用外部合约，防止重入
        auctionMap[tokenId] = auction;

        emit AuctionCreated(address(auction), tokenId);
        return address(auction);
    }

    function getAuctions() external view returns (address[] memory) {
        return auctions;
    }

    function getAuction(uint256 tokenId) external view returns (address) {
        require(tokenId < auctions.length, "tokenId out of bounds");
        return auctions[tokenId];
    }
}
