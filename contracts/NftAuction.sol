// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import "hardhat/console.sol";

contract NftAuction is Initializable, UUPSUpgradeable {
    // 拍卖结构体
    struct Auction {
        address seller; // 卖家
        uint256 duration; // 拍卖持续时间
        uint256 startingPrice; // 起始价格
        uint256 startTime; //拍卖开始时间
        bool ended; // 是否结束
        address highestBidder; // 最高出价者
        uint256 highestBid; // 最高出价
        address nftContract; // NFT合约地址
        uint256 tokenId; // NFT tokenId
        //参与竞价的资产类型
        //0:ETH
        //1:ERC20
        address tokenAddress;
    }
    //状态变量
    mapping(uint256 => Auction) public auctions;
    //下一个拍卖id
    uint256 public nextAuctionId;
    //管理员地址
    address public admin;

    // 资产类型对应的价格合约地址
    mapping(address => AggregatorV3Interface) public priceFeeds;

    // 初始化合约
    function initialize() public initializer {
        admin = msg.sender;
    }

    // 设置资产类型对应的价格合约地址
    function setPriceFeed(address _tokenAddress, address _priceFeed) public {
        priceFeeds[_tokenAddress] = AggregatorV3Interface(_priceFeed);
    }

    // 获取资产类型对应的最新价格
    function getChainlinkPrice(
        address _tokenAddress
    ) public view returns (int) {
        AggregatorV3Interface priceFeed = priceFeeds[_tokenAddress];
        (, int answer, , , ) = priceFeed.latestRoundData();
        return answer;
    }

    // 创建拍卖
    function createAuction(
        uint256 _duration,
        uint256 _startingPrice,
        address _nftAddress,
        uint256 _tokenId
    ) public {
        // 检查是否是管理员
        require(msg.sender == admin, "Only admin can create auction");
        // 检查持续时长和起始价格是否大于0
        require(_duration > 10, "Duration must be greater than 10s");
        // 检查起始价格是否大于0
        require(_startingPrice > 0, "Starting price must be greater than 0");

        // 转移NFT到合约
        IERC721(_nftAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        auctions[nextAuctionId] = Auction({
            seller: msg.sender, // 卖家地址
            duration: _duration, // 持续时长
            startingPrice: _startingPrice, // 起始价格
            ended: false, // 是否结束
            highestBidder: address(0), // 最高出价者
            highestBid: 0, // 最高出价
            startTime: block.timestamp, // 拍卖开始时间
            nftContract: _nftAddress, // NFT合约地址
            tokenId: _tokenId, // NFT tokenId
            tokenAddress: address(0) // 参与竞价的资产类型
        });

        nextAuctionId++; // 下一个拍卖id加1
    }

    // 出价
    function bid(
        uint256 _auctionId,
        uint256 amount,
        address _tokenAddress
    ) external payable {
        Auction storage auction = auctions[_auctionId];//获取拍卖信息
        // 检查拍卖是否存在
        require(_auctionId < nextAuctionId, "Auction does not exist");
        // 检查拍卖是否已经开始
        require(
            block.timestamp >= auction.startTime &&
                block.timestamp < auction.startTime + auction.duration,
            "Auction has not started"
        );
        // 检查拍卖是否已经结束
        require(!auction.ended, "Auction has ended");
        // 检查出价是否大于起始价格
        require(
            msg.value > auction.startingPrice,
            "Bid must be greater than starting price"
        );

        // 检查出价是否大于最高出价
        require(
            msg.value > auction.highestBid,
            "Bid must be greater than highest bid"
        );

        uint payValue;

        if (_tokenAddress != address(0)) {
            // ERC20资产类型
            payValue = amount * uint(getChainlinkPrice(_tokenAddress));
        } else {
            //ETH资产类型
            amount = msg.value;
            payValue = amount * uint(getChainlinkPrice(address(0)));
        }

        //起始价格的价值
        uint startPriceValue = auction.startingPrice *
            uint(getChainlinkPrice(auction.tokenAddress));

        //当前最高出价的价值
        uint highestBidValue = auction.highestBid *
            uint(getChainlinkPrice(auction.tokenAddress));

        // 检查出价是否大于起始价格的价值
        require(
            payValue > startPriceValue,
            "Bid must be greater than starting price value"
        );
        // 检查出价是否大于当前最高出价的价值
        require(
            payValue > highestBidValue,
            "Bid must be greater than highest bid value"
        );

        //转移ERC20到合约
        if(_tokenAddress != address(0)){
            ERC20(_tokenAddress).transferFrom(msg.sender, address(this), amount);
        }

        //退还前最高价
        if (auction.highestBid > 0) {
            // 退还前最高价的资产
            if (auction.tokenAddress == address(0)) {
                // ETH类型
                payable(auction.highestBidder).transfer(auction.highestBid);
            } else {
                // ERC资产类型
                // 退还前最高价的资产到前最高价者
                IERC20(auction.tokenAddress).transfer(
                    auction.highestBidder,
                    auction.highestBid
                );
            }
        }

        // 更新资产类型
        auction.tokenAddress = _tokenAddress;
        // 更新最高出价
        auction.highestBid = amount;
        // 更新最高出价者
        auction.highestBidder = msg.sender;
    }

    //结束拍卖
    function endAuction(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];
        // 检查拍卖是否存在
        require(_auctionId < nextAuctionId, "Auction does not exist");
        // 检查拍卖是否已经结束
        require(!auction.ended, "Auction has already ended");
        // 检查当前时间是否超过拍卖持续时间
        require(
            block.timestamp >= auction.startTime + auction.duration,
            "Auction duration has not ended"
        );

        // 先标记拍卖已结束，防止重入
        auction.ended = true;
        // 转移剩余的资金给卖家
        // payable(address(this)).transfer(address(this).balance);
    }
    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        require(msg.sender == admin, "Only admin can upgrade");
    }

    // 处理ERC721接收回调
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}