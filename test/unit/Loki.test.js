const { network, ethers } = require("hardhat")
const {
  developmentChains,
  networkConfig,
  abi,
} = require("../../helper-hardhat-config.js")
const { assert, expect } = require("chai")

describe("Loki unit tests", function () {
  let deployer, whale, matrixUNO, deposit, loki, usdc
  beforeEach(async function () {
    ;[deployer] = await ethers.getSigners()
    // USDC whale
    whale = await ethers.getSigner("0x77245082fdbf9c88dd0f6da50963b283e3ed726f")
    usdc = await ethers.getContractAt(
      abi,
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    )
    deposit = await ethers.getContract("deposit")
    //matrixUNO = await ethers.getContract("MatrixUNO")
    //loki = await ethers.getContract("Loki")
  })
  describe("PRELIMINARY TESTS", function () {
    it("whale should have large USDC balance", async function () {
      const bal = await usdc.balanceOf(whale.address)
      //console.log(bal.toString())
      assert.isAbove(bal, 1000000000)
    })
    it("first hardhat account should have zero USDC", async function () {
      const bal = await usdc.balanceOf(deployer.address)
      //console.log(bal.toString())
      assert.equal(bal.toString(), "0")
    })
  })
  describe("enterPool", function () {})
})
