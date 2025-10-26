// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./Auction.sol";
import {console} from "forge-std/console.sol";

contract AuctionV2 is Auction {
  function hello() public pure returns (string memory) {
    return "hello";
  }
}
