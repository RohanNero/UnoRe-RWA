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
  let asset

  args = [
    networkConfig[chainId]["stbtAddress"],
    networkConfig[chainId]["poolAddress"],
    networkConfig[chainId]["unoAddress"],
    networkConfig[chainId]["sanctionsAddress"],
    networkConfig[chainId]["stables"],
    networkConfig[chainId]["interval"],
  ]
  //console.log(args)
  //console.log(deployer)

  matrixUno = await deploy("MatrixUno", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: networkConfig[chainId].blockConfirmations,
    gasLimit: "7000000",
  })

  if (!developmentChains.includes(network.name)) {
    log("Verifying contract...")
    await verify(matrixUno.address, args)
  }
}

module.exports.tags = ["all", "main", "matrix", "matrixUno"]