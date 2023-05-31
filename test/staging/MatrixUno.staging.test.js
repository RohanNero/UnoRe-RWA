const { network, ethers } = require("hardhat")
const hre = require("hardhat")
const { setCode } = require("@nomicfoundation/hardhat-network-helpers")
const {
  developmentChains,
  networkConfig,
  usdcAbi,
  stbtAbi,
} = require("../../helper-hardhat-config.js")
const { assert, expect } = require("chai")

/** Steps to testing on Goerli:
 * 1. call stake with 50,000 USDC and ensure that xUNO was sent to the staker
 * 2. call unstake with 50,000 xUNO an ensure that 50,500 USDC is sent to the user (2000 STBT needs to be sent to vault prior to unstake)
 */

developmentChains.includes(network.name)
  ? describe.skip
  : describe("Ethereum Goerli tests", function () {
      let deployer, vault, usdc, stbt
      beforeEach(async function () {})
      describe("stake", function () {
        it("allows users to stake stablecoins for xUNO", async function () {
          const initialShares = await vault.balanceOf(deployer.address)
          //await vault.stake()
          const finalShares = await vault.balanceOf(deployer.address)
          console.log("InitialShares:", initialShares.toString())
        })
      })
      describe("unstake", function () {
        it("allows users to unstake xUNO for their initial stablecoin deposit plus rewards earned", async function () {})
      })
    })
