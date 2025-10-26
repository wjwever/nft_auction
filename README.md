## NFT拍卖市场

**实现一个NFT拍卖市场，出售者（Seller）可以把自己的NFT 上架市场，拍卖者（Bidder）围绕NFT进行出价。拍卖结束，NFT转给最高出价者，Seller获取相应的拍卖金额。**

## Feature

* Seller 可以允许用户 使用ETH 和 ERC20代币进行拍卖
* 预言机（Oracle）集成，以获取最新的ETH/ERC20价格
* 工厂模式集成，使用类似于 Uniswap V2 的工厂模式，管理每场拍卖。
* 拍卖合约支持UUPS完成合约升级

## TODO

* 跨链拍卖，使用 Chainlink 的 CCIP 功能，实现 NFT 跨链拍卖。
* 更充分的测试
* 前端页面集成
