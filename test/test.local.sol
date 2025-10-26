// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Auction} from "../src/Auction.sol";
import {AuctionV2} from "../src/AuctionV2.sol";
import {AuctionFactory} from "../src/Factory.sol";
import {MyToken} from "../src/MyToken.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {ETHFeed, MyTokenFeed} from "../src/MockAggregatorV3.sol";
import {console} from "forge-std/console.sol";

contract TestAuction is Test {
    AuctionFactory public factory;
    MyNFT public nft;
    MyToken public token;
    ETHFeed public ethFeed;
    MyTokenFeed public tokenFeed;

    Auction implV1;

    address user0 = vm.addr(1);
    address user1 = vm.addr(2);
    address user2 = vm.addr(3);
    address user3 = vm.addr(4);

    struct Param {
        address creator; // the person who add the auction
        uint256 startPrice;
        uint256 nftId;
        uint256 lockTime;
        address auctionAddr;
        uint256 auctionId;
    }

    function setUp() public {
        nft = new MyNFT();
        token = new MyToken();
        ethFeed = new ETHFeed();
        tokenFeed = new MyTokenFeed();

        implV1 = new Auction();
        factory = new AuctionFactory(address(implV1));

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);

        token.transfer(user1, 10 ether);
        token.transfer(user2, 10 ether);
        token.transfer(user3, 10 ether);
    }

    function test_mint_nft()  public {
        string
            memory URI = "https://bafybeiaal6hb63cqbnedvwderv6s7ny3thsdiu6slqabgv3ldcwliekeea.ipfs.dweb.link?filename=my_nft_meta.json";
        uint256 nftId = nft.safeMint(user0, URI);
        vm.assertEq(nftId, 1);
        assertEq(nft.ownerOf(nftId), user0);
    }

    function setUpCase() public returns (address, uint256) {
        // mint nft 1to user0
        string
            memory URI = "https://bafybeiaal6hb63cqbnedvwderv6s7ny3thsdiu6slqabgv3ldcwliekeea.ipfs.dweb.link?filename=my_nft_meta.json";
        uint256 nftId = nft.safeMint(user0, URI);

        // user0 create a auction
        vm.startPrank(user0);
        nft.approve(address(factory), nftId);
        address proxyAddr = factory.addAuction(
            address(nft),
            nftId,
            0.1 ether,
            120
        );
        Auction auction = Auction(proxyAddr);
        auction.setPriceFeed(address(0), address(ethFeed));
        auction.setPriceFeed(address(token), address(tokenFeed));
        vm.stopPrank();
        return (proxyAddr, nftId);
    }

    function test_add_auction() public returns (address) {
        (address proxyAddr, uint256 nftId) = setUpCase();
        assertEq(proxyAddr, factory.getAuction(address(nft), nftId)); 
        assertEq(proxyAddr, factory.computeProxyAddress(address(nft), nftId, user0, 0.1 ether, 120));
        Auction auction = Auction(proxyAddr);

        // test auction params
        assert(auction.owner() == user0);
        assert(auction._nftAddr() == address(nft));
        assert(auction._startTime() <= block.timestamp);
        assert(auction._lockTime() == 120);
        assert(auction._highestUSD() == 0.1 ether);
        assert(auction._highestBidder() == address(0));
        assert(auction._tokenAddr() == address(0));
        assert(auction._amount() == 0);
        assert(auction._ended() == false);

        // nft1 belongs to auction
        assertEq(nft.ownerOf(nftId), proxyAddr);
        return proxyAddr;
    }

    function test_bid() public {
        (address proxyAddr, uint256 nftId) = setUpCase();
        Auction auction = Auction(proxyAddr);

        vm.prank(user1);
        auction.bidByEther{value: 1 ether}();
        assert(proxyAddr.balance == 1 ether);

        vm.prank(user2);
        console.log(proxyAddr.balance);
        auction.bidByEther{value: 2 ether}();
        console.log(proxyAddr.balance);
        assert(proxyAddr.balance == 2 ether);

        vm.startPrank(user3);
        token.approve(address(auction), 2 ether);
        auction.bidByToken(address(token), 2 ether);
        vm.stopPrank();

        assert(proxyAddr.balance == 0);
        assert(auction._highestBidder() == user3);
        assert(auction._amount() == 2 ether);

        // test update
        AuctionV2 implV2 = new AuctionV2();
        vm.startPrank(user0);
        auction.upgradeToAndCall(address(implV2), "");

        AuctionV2 auctionV2 = AuctionV2(proxyAddr);
        assertEq(auctionV2.hello(), "hello");

        // test end
        vm.warp(block.timestamp + 120);
        auctionV2.endBid();
        assert(nft.ownerOf(1) == user3);
        vm.stopPrank();
    }
    // TODO add more test cases
}
