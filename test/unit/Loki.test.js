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
    const provider = new ethers.providers.JsonRpcProvider(
      "http://localhost:8545"
    )
    await provider.send("hardhat_impersonateAccount", [
      "0x171cda359aa49E46Dec45F375ad6c256fdFBD420",
    ])
    whale = provider.getSigner("0x171cda359aa49E46Dec45F375ad6c256fdFBD420")
    // This method kept throwing error messages from time to time so now he is green :p
    //whale = await ethers.getSigner("0x171cda359aa49E46Dec45F375ad6c256fdFBD420")
    //console.log(whale)

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
      const bal = await usdc.balanceOf(whale._address)
      //console.log(bal.toString())
      assert.isAbove(bal, 1000000000)
    })
    it("first hardhat account should have zero USDC", async function () {
      const bal = await usdc.balanceOf(deployer.address)
      //console.log(bal.toString())
      assert.equal(bal.toString(), "0")
    })
    it("should return expected values", async function () {
      const decimals = await lpToken.decimals({ gasLimit: 300000 })
      const name = await lpToken.name()
      const symbol = await lpToken.symbol()
      const bal = await lpToken.balanceOf(gauge.address, { gasLimit: 300000 })
      const balances = await lpToken.get_balances({ gasLimit: 300000 })
      // console.log("balances:", balances.toString())
      // console.log("decimals:", decimals.toString())
      // console.log("gauge lpToken bal:", bal.toString())
      // console.log("pool name:", name)
      // console.log("pool symbol:", symbol)
      assert.equal(decimals.toString(), "18")
      assert.isAbove(bal, 1000000000)
    })
    it("should allow whale to swap USDC for 3CRV", async function () {
      const oldbal = await threeCRV.balanceOf(whale._address, {
        gasLimit: 300000,
      })
      //console.log(whale)
      await usdc.connect(whale).approve(stableSwap.address, 550000000000000)
      const amounts = [0, 5448200000, 0]
      // left off right here, trying to call add_liquidity with an amount of USDC for 3CRV
      await stableSwap.connect(whale).add_liquidity(amounts, 1000000, {
        gasLimit: 30000000,
      })
      const newBal = await threeCRV.balanceOf(whale._address, {
        gasLimit: 300000,
      })
      const calcAmount = await stableSwap.calc_token_amount(
        [0, 5500, 0],
        true,
        {
          gasLimit: 300000,
        }
      )
      //console.log("calc token amount:", calcAmount.toString())
      //console.log(stableSwap.functions)
      // console.log(
      //   "whale usdc balance:",
      //   (await usdc.balanceOf(whale.address)).toString()
      // )
      // console.log(
      //   "usdc address:",
      //   (await stableSwap.coins(1, { gasLimit: 300000 })).toString()
      // )
      // console.log("old balance:", oldbal.toString())
      // console.log("new balance:", newBal.toString())
      //console.log(stableSwap)
      //console.log(threeCRV)
    })
    it("should transfer LP tokens to whale after 3CRV deposit", async function () {
      const usdcBal = await usdc.balanceOf(whale._address)
      const crvAllowance = await threeCRV.allowance(
        whale._address,
        lpToken.address
      )
      // console.log("old 3CRV allowance:", crvAllowance.toString())
      // console.log("whale USDC balance:", usdcBal.toString())
      // console.log("whale address:", whale._address)
      //console.log(lpToken.functions)
      const oldLpBal = await lpToken.balanceOf(whale._address, {
        gasLimit: 300000,
      })
      const oldCrvBal = await threeCRV.balanceOf(whale._address, {
        gasLimit: 300000,
      })
      await usdc
        .connect(whale)
        .approve(stableSwap.address, 100000000000, { gasLimit: 300000 })
      const crvAmounts = [0, 100000000000, 0]

      await stableSwap.connect(whale).add_liquidity(crvAmounts, 1000000, {
        gasLimit: 30000000,
      })
      const newCrvBal = await threeCRV.balanceOf(whale._address, {
        gasLimit: 300000,
      })
      // deposit tx takes: (uint256[2], uint256) or (uint256[2], uint256, address)
      const amounts = [0, 1000000000000]
      if (crvAllowance < amounts[1]) {
        await threeCRV
          .connect(whale)
          .approve(lpToken.address, "10000000000000000", {
            gasLimit: 300000,
          })
      }
      await lpToken
        .connect(whale)
        ["add_liquidity(uint256[2],uint256)"](amounts, 1000000, {
          gasLimit: 3000000,
        })
      const newLpBal = await lpToken.balanceOf(whale._address, {
        gasLimit: 300000,
      })

      const newCrvAllowance = await threeCRV.allowance(
        whale._address,
        lpToken.address
      )
      // console.log("new 3CRV allownace:", newCrvAllowance.toString())
      // console.log("lpToken address:", lpToken.address)
      // console.log("old 3CRV balance:", oldCrvBal.toString())
      // console.log("new 3CRV balance:", newCrvBal.toString())
      // console.log("old LP token balance:", oldLpBal.toString())
      // console.log("new LP token balance:", newLpBal.toString())
      assert.isAbove(newLpBal, oldLpBal)
    })
  })
  describe("enterPool", function () {})
})
