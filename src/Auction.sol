// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

//import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
//import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";
import {AuctionFactory} from "./Factory.sol";
import "./MyNFT.sol";
import {console} from "forge-std/console.sol";

//contract Auction is Initializable, UUPSUpgradeable {
contract Auction is IERC721Receiver, UUPSUpgradeable, OwnableUpgradeable {
  mapping(address => address) internal _priceFeeds;
  address public _nftAddr;
  uint256 public _nftTokenId;
  uint256 public _startTime;
  uint256 public _lockTime;
  int256 public _highestUSD;
  address public _highestBidder;
  address public _tokenAddr; // ERC20 合约地址
  uint256 public _amount; // 最高出价
  bool public _ended; // 整个交易是否结束
  // -------------modifier-------------------
  modifier PosInt(int256 val) {
    require(val > 0, "require postive value");
    _;
  }

  modifier PosUInt(uint256 val) {
    require(val > 0, "require postive value");
    _;
  }

  modifier ValidAddress(address addr) {
    require(addr != address(0), "require valid address");
    _;
  }

  function initialize(
    address seller,
    address nftAddress,
    uint256 nftId,
    int256 startPrice,
    uint256 lockTime
  ) external ValidAddress(seller) ValidAddress(nftAddress) PosUInt(nftId) PosInt(startPrice) PosUInt(lockTime) initializer {
    __Ownable_init(msg.sender);
    __UUPSUpgradeable_init();

    _transferOwnership(seller);

    require(
      IERC721(nftAddress).ownerOf(nftId) == owner(),
      "nft not owned by seller"
    );

    //_seller = seller;
    _nftAddr = nftAddress;
    _nftTokenId = nftId;
    _startTime = block.timestamp;
    _lockTime = lockTime;
    _highestUSD = startPrice;
    _highestBidder = address(0);
    _tokenAddr = address(0);
    _amount = 0;
    _ended = false;
  }

  //receive() external payable {}

  // UUPS 升级授权
  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyOwner {}

  function setPriceFeed(address addr, address aggAddr) external ValidAddress(aggAddr) onlyOwner {
    _priceFeeds[addr] = aggAddr;
  }

  function getUSD(
    address tokenAddr,
    uint256 amount
  ) internal view returns (int256) {
    address aggAddr = _priceFeeds[tokenAddr];
    require(aggAddr != address(0), "unsupported coin");
    AggregatorV3Interface priceFeed = AggregatorV3Interface(aggAddr);
    // prettier-ignore
    (
      /* uint80 roundId */,
      int256 answer,
      /*uint256 startedAt*/,
      /*uint256 updatedAt*/,
      /*uint80 answeredInRound*/
    ) = priceFeed.latestRoundData();
      uint8 decimal = priceFeed.decimals();

      // TODO check overflow
      int256 price = (int256(amount) * answer) / int256(10 ** decimal); // ETH 和token 都是 18 位小数
      console.log("getUSD", amount, tokenAddr, uint256(price));
      return price;
  }

  function bidByEther() external payable {
    require(block.timestamp < _startTime + _lockTime, "auction ended");
    uint256 amount = msg.value;
    int256 usdAmount = getUSD(address(0), amount);
    require(usdAmount > _highestUSD, "price is low");
    // refund
    if (_tokenAddr == address(0)) {
      payable(_highestBidder).transfer(_amount);
    } else {
      IERC20(_tokenAddr).transfer(_highestBidder, _amount);
    }
    _highestBidder = msg.sender;
    _highestUSD = usdAmount;
    _tokenAddr = address(0);
    _amount = amount;
  }

  // 拍卖
  function bidByToken(address tokenAddr, uint256 amount) public {
    require(block.timestamp < _startTime + _lockTime, "auction ended");
    int256 usdAmount = getUSD(tokenAddr, amount);
    require(usdAmount > _highestUSD, "price is low");

    // refund
    if (_tokenAddr == address(0)) {
      payable(_highestBidder).transfer(_amount);
    } else {
      IERC20(_tokenAddr).transfer(_highestBidder, _amount);
    }

    IERC20(tokenAddr).transferFrom(msg.sender, address(this), amount);

    _highestBidder = msg.sender;
    _highestUSD = usdAmount;
    _tokenAddr = tokenAddr;
    _amount = amount;
  }

  // 结束拍卖
  function endBid() external payable virtual onlyOwner {
    require(
      block.timestamp >= _startTime + _lockTime,
      "auction is still under bidding"
    );
    require(_ended == false, "already withdrawed");
    _ended = true;
    // no one bids
    if (_highestBidder == address(0)) {
      MyNFT(_nftAddr).safeTransferFrom(
        address(this),
        owner(),
        _nftTokenId
      );
    } else {
      // recive eth or token
      if (_tokenAddr == address(0)) {
        // TODO use safe transfer
        payable(owner()).transfer(_amount);
      } else {
        IERC20(_tokenAddr).transfer(owner(), _amount);
      }
      // transfer nft
      MyNFT(_nftAddr).safeTransferFrom(
        address(this),
        _highestBidder,
        _nftTokenId
      );
    }
    address nft_owner = MyNFT(_nftAddr).ownerOf(_nftTokenId);
    console.log("nft owner", nft_owner);
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external pure override returns (bytes4) {
    // 这里可以添加自定义逻辑

    // 必须返回这个固定的魔法值
    return this.onERC721Received.selector;
  } // }
  // function _authorizeUpgrade(address) internal view override {
  //     // 只有管理员可以升级合约
  //     require(msg.sender == _owner, "Only admin can upgrade");
  }
