const { deployments, getNamedAccounts, network, ethers } = require("hardhat")
const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat-config.js")
const { verify } = require("../utils/verify.js")

const FUND_AMOUNT = "1000000000000000000000"

module.exports = async ({ deployments, getNamedAccounts }) => {
  const { deployer } = await getNamedAccounts()
  const { deploy, log } = deployments
  const chainId = await getChainId()
  //log(chainId)

  if (developmentChains.includes(network.name)) {
    vrfCoordinator = await ethers.getContract("VRFCoordinatorV2Mock")
    vrfCoordinatorAddress = vrfCoordinator.address
    const transactionResponse = await vrfCoordinator.createSubscription()
    const transactionReceipt = await transactionResponse.wait()
    subscriptionId = transactionReceipt.events[0].args.subId
    //log(subscriptionId.toString())
    // Fund the subscription
    // Our mock makes it so we don't actually have to worry about sending fund
    await vrfCoordinator.fundSubscription(subscriptionId, FUND_AMOUNT)
  } else {
    vrfCoordinatorAddress = networkConfig[chainId]["vrfCoordinator"]
    subscriptionId = networkConfig[chainId]["subId"]
  }

  args = [
    vrfCoordinatorAddress,
    networkConfig[chainId]["keyHash"],
    subscriptionId,
    networkConfig[chainId]["callbackGaslimit"],
  ]

  const jury = await deploy("VRFJury", {
    from: deployer,
    log: true,
    args: args,
  })

  if (!developmentChains.includes(network.name)) {
    log("Verifying contract...")
    await verify(jury.address, args)
  }
}

module.exports.tags = ["all", "main", "jury"]
