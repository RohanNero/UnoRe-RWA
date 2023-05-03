const { network, ethers } = require("hardhat")
const {
  developmentChains,
  networkConfig,
  abi,
  lpAbi,
  gaugeAbi,
  threeCRVAbi,
  stableSwapAbi,
} = require("../../helper-hardhat-config.js")
const { assert, expect } = require("chai")

describe("Loki unit tests", function () {
  let deployer,
    whale,
    matrixUNO,
    deposit,
    loki,
    usdc,
    lpToken,
    gauge,
    threeCRV,
    stableSwap
  beforeEach(async function () {
    ;[deployer] = await ethers.getSigners()
    // USDC whale
    whale = await ethers.getSigner("0x77245082fdbf9c88dd0f6da50963b283e3ed726f")
    usdc = await ethers.getContractAt(
      abi,
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    )
    lpToken = await ethers.getContractAt(
      lpAbi,
      "0x892d701d94a43bdbcb5ea28891daca2fa22a690b"
    )
    gauge = await ethers.getContractAt(
      gaugeAbi,
      "0x4B6911E1aE9519640d417AcE509B9928D2F8377B"
    )
    threeCRV = await ethers.getContractAt(
      threeCRVAbi,
      "0x6c3f90f043a72fa612cbac8115ee7e52bde6e490"
    )
    stableSwap = await ethers.getContractAt(
      stableSwapAbi,
      "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
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
    it("should allow whale to swap USDC for 3CRV", async function () {
      const oldbal = await threeCRV.balanceOf(whale.address, {
        gasLimit: 300000,
      })
      await usdc.approve(stableSwap.address, 5548200000)
      const amounts = [0, 5448200000, 0]
      // left off right here, trying to call add_liquidity with an amount of USDC for 3CRV
      // await stableSwap.add_liquidity([0, 5448200000, 0], 100, {
      //   gasLimit: 3000000,
      // })
      const newBal = await threeCRV.balanceOf(whale.address, {
        gasLimit: 300000,
      })
      console.log((await usdc.balanceOf(whale.address)).toString())
      console.log(oldbal.toString())
      console.log(newBal.toString())
      //console.log(stableSwap)
      //console.log(threeCRV)
    })
    it("should return expected values", async function () {
      const decimals = await lpToken.decimals({ gasLimit: 300000 })
      const name = await lpToken.name()
      const symbol = await lpToken.symbol()
      const bal = await lpToken.balanceOf(gauge.address, { gasLimit: 300000 })
      const balances = await lpToken.get_balances({ gasLimit: 300000 })
      console.log(balances.toString())
      //console.log(decimals.toString())
      //console.log(bal.toString())
      //console.log(name)
      //console.log(symbol)
      //console.log(bal.toString())
      assert.equal(decimals.toString(), "18")
      assert.isAbove(bal, 1000000000)
    })
    it("should transfer LP tokens to whale after deposit", async function () {
      const oldBal = await lpToken.balanceOf(whale.address, {
        gasLimit: 300000,
      })

      //await usdc.approve(lpToken.address, 1000000)
      // deposit tx takes: (uint256[2], uint256) or (uint256[2], uint256, address)
      const amounts = [1000000, 0]
      //await lpToken.add_liquidity(amounts, 0, { gasLimit: 300000 })
      const newBal = await lpToken.balanceOf(whale.address, {
        gasLimit: 300000,
      })
      //console.log(lpToken.functions)
      console.log(oldBal.toString())
      console.log(newBal.toString())
    })
  })
  describe("enterPool", function () {})
})
