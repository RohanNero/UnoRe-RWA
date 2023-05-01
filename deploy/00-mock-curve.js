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

  if (developmentChains.includes(network.name)) {
  } else {
  }

  mapleUNO = await deploy("deposit", {
    from: deployer,
    log: true,
    waitConfirmations: networkConfig[chainId].blockConfirmations,
  })

  if (!developmentChains.includes(network.name)) {
    log("Verifying contract...")
    await verify(mapleUNO.address, args)
  }
}

module.exports.tags = ["all", "mock", "curve"]
