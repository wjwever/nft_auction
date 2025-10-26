// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";
import "./Auction.sol";

// contract AuctionFactory is Initializable, UUPSUpgradeable {
contract AuctionFactory is Ownable {
  address _owner;
  address public implementation;
  mapping(bytes32 => address) public auctionProxies;

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

  // --------------event and error-----------------
  event AuctionCreated(
    address indexed proxy,
    address indexed nftAddress,
    uint256 nftId
  );
  event ImplUpgraded(address impl);
  error AuctionNotExist(address nftAddress, uint256 nftId);

  //-----------------functions------------------
  constructor(address _implementation) Ownable(msg.sender) {
    implementation = _implementation;
    _transferOwnership(msg.sender);
  }

  function upgradeImpl(address newImpl) external onlyOwner ValidAddress(newImpl) {
    implementation = newImpl;
    emit ImplUpgraded(implementation);
  }

  function addAuction(
    address nftAddress,
    uint256 nftId,
    int256 startPrice,
    uint256 lockTime
  ) external ValidAddress(nftAddress) PosInt(startPrice) PosUInt(lockTime) returns (address) {
    require(
      IERC721(nftAddress).getApproved(nftId) == address(this),
      "approve frist"
    );
    bytes memory initData = abi.encodeWithSelector(
      Auction.initialize.selector,
      msg.sender,
      nftAddress,
      nftId,
      startPrice,
      lockTime
    );

    bytes32 salt = keccak256(abi.encodePacked(nftAddress, nftId));
    require(auctionProxies[salt] == address(0), "auction already exists");

    // 部署代理合约，指向 implementation
    ERC1967Proxy proxy = new ERC1967Proxy{salt: salt}(
      implementation,
      initData
    );

    IERC721(nftAddress).safeTransferFrom(msg.sender, address(proxy), nftId);

    auctionProxies[salt] = address(proxy);
    emit AuctionCreated(address(proxy), nftAddress, nftId);

    return address(proxy);
  }

  function getAuction(
    address nftAddress,
    uint256 nftId
  ) public view returns (address) {
    bytes32 salt = keccak256(abi.encodePacked(nftAddress, nftId));
    if (auctionProxies[salt] == address(0)) {
      revert AuctionNotExist(nftAddress, nftId);
    }
    return auctionProxies[salt];
  }

  function computeProxyAddress(
    address nftAddress,
    uint256 nftId,
    address seller,
    int256 startPrice,
    uint256 lockTime
  ) public view returns (address) {
    bytes memory initData = abi.encodeWithSelector(
      Auction.initialize.selector,
      seller,
      nftAddress,
      nftId,
      startPrice,
      lockTime
    );
    bytes32 salt = keccak256(abi.encodePacked(nftAddress, nftId));
    bytes memory creationCode = abi.encodePacked(
      type(ERC1967Proxy).creationCode,
      abi.encode(implementation, initData)
    );

    bytes32 hash = keccak256(
      abi.encodePacked(
        bytes1(0xff),
        address(this),
        salt,
        keccak256(creationCode)
    )
    );

    return address(uint160(uint256(hash)));
  }
}
