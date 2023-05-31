const { deployments, getNamedAccounts, network, ethers } = require("hardhat")
const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat-config.js")
const { verify } = require("../utils/verify.js")

module.exports = async ({ deployments, getNamedAccounts }) => {
  const { deployer } = await getNamedAccounts()
  const { deploy, log } = deployments
  const chainId = await getChainId()
  //log(chainId)

  if (chainId == 5) {
    const MockCurvePool = await deploy("MockCurvePool", {
      from: deployer,
      log: true,
      waitConfirmations: networkConfig[chainId].blockConfirmations,
    })
  }
}

module.exports.tags = ["all", "mock", "curve"]
