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
    const mockCurvePool = await deploy("MockCurvePool", {
      from: deployer,
      log: true,
      waitConfirmations: networkConfig[chainId].blockConfirmations,
    })

    const mockSanctionsList = await deploy("MockSanctionsList", {
      from: deployer,
      log: true,
      waitConfirmations: networkConfig[chainId].blockConfirmations,
    })

    const mockUSDT = await deploy("MockUSDT", {
      from: deployer,
      log: true,
      waitConfirmations: networkConfig[chainId].blockConfirmations,
    })

    log("Verifying MockCurvePool...")
    await verify(mockCurvePool.address)

    log("Verifying MockSanctionsList...")
    await verify(mockSanctionsList.address)

    log("Verifying MockUSDT...")
    await verify(mockUSDT.address)
  }
}

module.exports.tags = ["all", "mocks", "matrix"]
