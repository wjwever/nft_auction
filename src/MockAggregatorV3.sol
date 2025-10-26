// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";

contract MockAggregatorV3 is AggregatorV3Interface {
  int256 _answer;
  string _desc;
  address _owner;

  constructor(int256 answer) {
    _owner = msg.sender;
    _answer = answer;
  }

  // function set(string memory desc, int256 answer) external {
  //     require(msg.sender == _owner, "Only Owner");
  //     _answer = answer;
  //     _desc = desc;
  // }

  function decimals() external pure returns (uint8) {
    return 18;
  }

  function description() external view returns (string memory) {
    return _desc;
  }

  function version() external pure returns (uint256) {
    return 0;
  }

  function getRoundData(
    uint80 _roundId
  )
  external
  view
  returns (
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  )
  {
    return (0, _answer, 0, 0, 0);
  }

  function latestRoundData()
  external
  view
  returns (
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  )
  {
    return (0, _answer, 0, 0, 0);
  }
}

contract ETHFeed is MockAggregatorV3 {
  constructor() MockAggregatorV3(1 ether) {}
}

contract MyTokenFeed is MockAggregatorV3 {
  constructor() MockAggregatorV3(2 ether) {}
}
