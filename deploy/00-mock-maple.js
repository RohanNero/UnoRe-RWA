const { deployments, getNamedAccounts, network, ethers } = require("hardhat")
const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat-config.js")

module.exports = async ({ deployments, getNamedAccounts }) => {
  const { deployer } = await getNamedAccounts()
  const { deploy, log } = deployments
  const chainId = await getChainId()
  //log(chainId)

  if (developmentChains.includes(network.name)) {
    /* Pool Constructor Args */
    // address manager_,
    // address asset_,
    // address destination_,
    // uint256 bootstrapMint_,
    // uint256 initialSupply_,
    // string memory name_,
    // string memory symbol_
    args = []
    const jury = await deploy("Pool", {
      from: deployer,
      log: true,
      args: args,
    })
  }
}

module.exports.tags = ["mock", "pool"]
