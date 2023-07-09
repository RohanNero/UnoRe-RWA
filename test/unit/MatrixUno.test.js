const { network, ethers } = require("hardhat")
const hre = require("hardhat")
const { setCode, time } = require("@nomicfoundation/hardhat-network-helpers")
const {
  developmentChains,
  networkConfig,
  usdcAbi,
  lpAbi,
  gaugeAbi,
  threeCRVAbi,
  stableSwapAbi,
  crvAbi,
  minterAbi,
  stbtAbi,
  stbtModeratorAbi,
} = require("../../helper-hardhat-config.js")
const { assert, expect } = require("chai")
const { JsonRpcProvider } = require("ethers")

describe.only("MatrixUno Unit Tests", function () {
  let deployer,
    whale,
    matrixUNO,
    loki,
    usdc,
    lpToken,
    gauge,
    threeCRV,
    stableSwap,
    crv,
    minter,
    sWhale,
    eWhale,
    stbt,
    stbtModerator,
    vault,
    stbtModeratorExecutor,
    stbtModeratorProposer
  //initialUsdcBal
  beforeEach(async function () {
    ;[deployer] = await ethers.getSigners()
    //console.log(network)

    // USDC whale
    const provider = new JsonRpcProvider("http://localhost:8545")
    // await provider.send("hardhat_impersonateAccount", [
    //   "0x171cda359aa49E46Dec45F375ad6c256fdFBD420",
    // ])
    whale = await ethers.getImpersonatedSigner(
      "0x171cda359aa49E46Dec45F375ad6c256fdFBD420"
    )
    // This method kept throwing error messages from time to time so now he is green :p
    //whale = await ethers.getSigner("0x171cda359aa49E46Dec45F375ad6c256fdFBD420")
    //console.log(whale)
    // 0x51250e5292006aF94Ff286d52729b58aB78A0465 - alot of STBT but no ETH for tx gas
    //sWhale = provider.getSigner("0x81BD585940501b583fD092BC8397F2119A96E5ba")
    sWhale = await ethers.getImpersonatedSigner(
      "0x81BD585940501b583fD092BC8397F2119A96E5ba"
    )
    eWhale = await ethers.getImpersonatedSigner(
      "0x868daB0b8E21EC0a48b726A1ccf25826c78C6d7F"
    )
    // stbtModerator = provider.getSigner(
    //   "0x22276A1BD16bc3052b362C2e0f65aacE04ed6F99"
    // )
    stbtModeratorExecutor = await ethers.getImpersonatedSigner(
      "0xd32a1441872774f30EC9C453983cf5C95a720123"
    )
    stbtModeratorProposer = await ethers.getImpersonatedSigner(
      "0x65FF5a67D8d7292Bd4Ea7B6CD863D9F3ca14f046"
    )
    usdc = await ethers.getContractAt(
      usdcAbi,
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
    crv = await ethers.getContractAt(
      crvAbi,
      "0xD533a949740bb3306d119CC777fa900bA034cd52"
    )
    minter = await ethers.getContractAt(
      minterAbi,
      "0xd061d61a4d941c39e5453435b6345dc261c2fce0"
    )
    stbt = await ethers.getContractAt(
      stbtAbi,
      "0x530824DA86689C9C17CdC2871Ff29B058345b44a"
    )
    vault = await ethers.getContract("MatrixUno")
    stbtModerator = await ethers.getContractAt(
      stbtModeratorAbi,
      "0x22276A1BD16bc3052b362C2e0f65aacE04ed6F99"
    )
    //initialUsdcBal = await usdc.balanceOf(whale.address)
    // deposit = await ethers.getContract("deposit")
    //matrixUNO = await ethers.getContract("MatrixUNO")
    //loki = await ethers.getContract("Loki")
  })
  /** MUST BE ON MAINNET FORK TO TEST THESE DESCRIBES */
  !developmentChains.includes(network.name)
    ? describe.skip
    : describe("Ethereum Mainnet Fork tests", function () {
        describe("stake", function () {
          it("STBT whale should have a high STBT balance", async function () {
            //console.log(sWhale)
            const initialBal = await stbt.balanceOf(sWhale.address, {
              gasLimit: 300000,
            })
            const string = initialBal.toString()
            const bal = string.slice(0, -18)
            // console.log("STBT whale address:", sWhale.address)
            // //console.log(stbt)
            // console.log("STBT balance:", initialBal.toString())
            // console.log("truncated balance:", bal)
            assert.isTrue(bal > 100000)
          })
          it("allow moderator to update the vault's STBT permissions", async function () {
            // console.log(stbt)
            // console.log(vault)
            const prePermissions = await stbt.permissions(vault.target)
            console.log("prepermissions:", prePermissions)
            // going to have to setPermission through `execute` function call
            if (prePermissions[0] == false) {
              const fiveEther = ethers.parseEther("5")
              await eWhale.sendTransaction({
                value: fiveEther,
                to: stbtModeratorProposer.address,
              })
              await eWhale.sendTransaction({
                value: fiveEther,
                to: stbtModeratorExecutor.address,
              })
              // await hre.network.provider.request({
              //   method: "hardhat_impersonateAccount",
              //   params: [stbtModeratorProposer.target],
              // })
              // Moderator arguments: address target,uint256 value,bytes calldata data,bytes32 predecessor,bytes32 salt,uint256 delay
              await stbtModerator
                .connect(stbtModeratorProposer)
                .schedule(
                  stbt.target,
                  0,
                  "0x47e640c000000000000000000000000097fd63d049089cd70d9d139ccf9338c81372de68000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000",
                  "0x0000000000000000000000000000000000000000000000000000000000000000",
                  "0x3235363030376561343437613862653633303530396531623764396132326335",
                  0,
                  { gasLimit: 300000 }
                )
              // await hre.network.provider.request({
              //   method: "hardhat_impersonateAccount",
              //   params: [stbtModeratorExecutor.address],
              // })
              await stbtModerator
                .connect(stbtModeratorExecutor)
                .execute(
                  stbt.target,
                  0,
                  "0x47e640c000000000000000000000000097fd63d049089cd70d9d139ccf9338c81372de68000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000",
                  "0x0000000000000000000000000000000000000000000000000000000000000000",
                  "0x3235363030376561343437613862653633303530396531623764396132326335"
                )
            }

            //console.log(stbtModerator.functions)
            //await stbtModerator.eggs(vault.target, [true, true, 0])
            // original function call
            // await stbt
            //   .connect(stbtModerator)
            //   .setPermission(vault.target, [true, true, 0])
            const postPermissions = await stbt.permissions(vault.target)
            const moderator = await stbt.moderator()
            console.log(prePermissions.toString())
            console.log(postPermissions.toString())
            console.log("vault address:", vault.target)
            console.log("moderator:", moderator)
            console.log("impersona:", stbtModerator.target)
            //console.log(stbt.interface)
            //assert.isTrue(postPermissions[1])
          })
          it("STBT whale should be able to deposit STBT", async function () {
            // await hre.network.provider.request({
            //   method: "hardhat_impersonateAccount",
            //   params: [sWhale.address],
            // })
            const stbtBalance = await stbt.balanceOf(sWhale.address)
            const stbtAllowance = await stbt.allowance(
              sWhale.address,
              vault.target
            )
            const stbtDeposit = ethers.parseUnits("200000", 18)
            const vaultStbtBalance = await stbt.balanceOf(vault.target)
            // console.log("stbt Balance:", stbtBalance.toString())
            // console.log("stbt Deposit:", stbtDeposit.toString())
            // console.log("stbt Allowance:", stbtAllowance.toString())
            // console.log("vault stbt balance:", vaultStbtBalance.toString())
            if (stbtAllowance.toString() < stbtDeposit.toString()) {
              await stbt.connect(sWhale).approve(vault.target, stbtDeposit, {
                gasLimit: 300000,
              })
              //console.log(stbtDeposit.toString(), "STBT approved!")
            }
            const half = Number(stbtDeposit) / 2
            if (vaultStbtBalance < half) {
              await vault.connect(sWhale).deposit(stbtDeposit, vault.target, {
                gasLimit: 300000,
              })
            }
            const endingVaultStbtBalance = await stbt.balanceOf(vault.target)
            //console.log(endingVaultStbtBalance.toString())
            assert.isTrue(endingVaultStbtBalance >= half)
          })
          it("vault should mint and hold xUNO after the STBT deposit", async function () {
            const vaultSharesBalance = await vault.balanceOf(vault.target)
            const vaultSharesBalanceSliced = vaultSharesBalance
              .toString()
              .slice(0, -18)
            //console.log(vaultSharesBalanceSliced)
            assert.isTrue(vaultSharesBalanceSliced >= 99999)
          })
          // Actual MatrixUno `stake()` function calls
          // it("reverts if `amount` input is zero", async function () {
          //   //console.log(vault)
          //   if (vault) {
          //     await expect(
          //       vault.connect(whale).stake(0, 1, 99, { gasLimit: 300000 })
          //     ).to.be.revertedWithCustomError(
          //       vault,
          //       "MatrixUno__ZeroAmountGiven"
          //     )
          //   }
          // })
          // it("reverts if `token` input is more than two", async function () {
          //   await expect(
          //     vault.connect(whale).stake(777, 3, 99, { gasLimit: 300000 })
          //   ).to.be.revertedWithCustomError(vault, "MatrixUno__InvalidTokenId")
          // })
          // The important one
          it("transfers the stablecoins from user to vault", async function () {
            const initialVaultUsdcBalance = await usdc.balanceOf(vault.target)
            console.log(whale)
            const usdcBalance = await usdc.balanceOf(whale.address)
            const usdcAllowance = await usdc.allowance(
              whale.address,
              vault.target
            )
            console.log("2")
            const usdcDeposit = 50000 * 1e6
            console.log("whale usdc balance:", usdcBalance.toString())
            console.log("vault usdc allowance:", usdcAllowance.toString())
            console.log(
              "initial vault usdc balance:",
              initialVaultUsdcBalance.toString()
            )
            //if (usdcAllowance < usdcDeposit) {
            await usdc
              .connect(whale)
              .approve(vault.target, usdcDeposit.toString())
            //}
            const updatedUsdcAllowance = await usdc.allowance(
              whale.address,
              vault.target
            )
            const totalClaimed = await vault.viewTotalClaimed()
            console.log(
              "updated usdc allowance:",
              updatedUsdcAllowance.toString()
            )
            console.log("total claimed:", totalClaimed.toString())
            console.log((await vault.balanceOf(vault.target)).toString())
            console.log("usdcDeposit:", usdcDeposit.toString())
            //if (initialVaultUsdcBalance < usdcDeposit) {
            const shares = await vault
              .connect(whale)
              .stake(usdcDeposit, 1, 99, { gasLimit: 300000 })
            //}
            //console.log("staked!")

            const finalVaultUsdcBalance = await usdc.balanceOf(vault.target)
            //console.log("final vault usdc balance:", finalVaultUsdcBalance.toString())
          })
          it("updates the user's balance for the staked stablecoin", async function () {
            const vaultBalance = await vault.viewStakedBalance(whale.address, 1)
            const totalClaimed = await vault.viewTotalClaimed()
            //console.log("whale usdc balance:", vaultBalance.toString())
            //console.log("total claimed:", totalClaimed.toString())
            // eventually need to make > into = since unstake should be working properly
            assert.isTrue(vaultBalance >= 50000000000 || totalClaimed > 0)
          })
          it("transfers xUNO to the user", async function () {
            const whalexUnoBalance = await vault.balanceOf(whale.address)
            const vaultxUnoBalance = await vault.balanceOf(vault.target)
            const vaultSymbol = await vault.symbol()
            const slicedWhaleBalance = whalexUnoBalance.toString().slice(0, -18)
            const totalClaimed = await vault.viewTotalClaimed()
            // console.log("whale xUNO balance:", whalexUnoBalance.toString())
            // console.log("vault xUNO balance:", vaultxUnoBalance.toString())
            // console.log("vault shares symbol:", vaultSymbol.toString())
            // console.log("total claimed:", totalClaimed.toString())
            assert.isTrue(slicedWhaleBalance > 1000 || totalClaimed > 0)
          })
          // come back to this test later
          // it("`transferFromAmount` is less than provided `amount` if vault doesn't have enough xUNO", async function () {})
        })
        describe("performUpkeep", function () {
          it("MOCK SENDING REWARDS", async function () {
            const initialVaultAssets = await stbt.balanceOf(vault.target)
            const thousandStbt = ethers.parseUnits("1000", 18)
            const slicedVaultAssets = initialVaultAssets
              .toString()
              .slice(0, -18)
            //if (slicedVaultAssets < 200000) {
            await stbt.connect(sWhale).transfer(vault.target, thousandStbt)
            console.log("mock stbt rewards distributed!")
            //}
          })
          it("should update reward info for the week", async function () {
            const interval = await vault.viewInterval()
            const initialWeek = await vault.viewCurrentPeriod()
            const initialInfo = await vault.viewRewardInfo(initialWeek)
            console.log("interval:", interval.toString())
            console.log("initialWeek:", initialWeek.toString())
            console.log(
              "rewards, vaultAssetBalance, previousWeekBalance, claimed, currentBalance, deposited, withdrawn"
            )
            console.log("initialInfo:", initialInfo.toString())

            const returnVal = await vault.checkUpkeep("0x")
            console.log("upkeepNeeded:", returnVal.upkeepNeeded)
            if (returnVal.upkeepNeeded == false) {
              await time.increase(86400)
            }
            const perform = await vault.performUpkeep("0x")
            await perform.wait(1)
            //console.log("Upkeep Performed!")
            const finalWeek = await vault.viewCurrentPeriod()
            const finalInfo = await vault.viewRewardInfo(initialWeek)
            const nextWeekInfo = await vault.viewRewardInfo(finalWeek)
            console.log("finalWeek:", finalWeek.toString())
            console.log("finalInfo:", finalInfo.toString())
            console.log("nextWeekInfo:", nextWeekInfo.toString())
          })
        })

        // VIEW FUNCTIONS / VIEW FUNCTIONS / VIEW FUNCTIONS / VIEW FUNCTIONS / VIEW FUNCTIONS //
        describe("viewPoolAddress", function () {
          it("returns the curve pool address", async function () {
            const value = await vault.viewPoolAddress()
            assert.equal(value, 0x892d701d94a43bdbcb5ea28891daca2fa22a690b)
          })
        })
        describe("viewUnoAddress", function () {
          it("returns Uno's EOA address", async function () {
            const value = await vault.viewUnoAddress()
            assert.equal(value, 0x81bd585940501b583fd092bc8397f2119a96e5ba)
          })
        })
        describe("viewStables", function () {
          it("returns addresses of DAI/UDSC/USDT used by this contract", async function () {
            const value = await vault.viewStables()
            assert.equal(value[0], 0x6b175474e89094c44da98b954eedeac495271d0f)
            assert.equal(value[1], 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48)
            assert.equal(value[2], 0xdac17f958d2ee523a2206206994597c13d831ec7)
          })
        })
        describe("viewSanctionsList", function () {
          it("returns the sanctionsList contract address", async function () {
            const value = await vault.viewSanctionsList()
            assert.equal(value, 0x40c57923924b5c5c5455c48d93317139addac8fb)
          })
        })
        describe("viewVaultStableBalance", function () {
          it("returns the total stable balance of the vault", async function () {
            const bal = await vault.viewVaultStableBalance()
            await usdc.connect(whale).transfer(vault.target, 777)
            const updatedBal = await vault.viewVaultStableBalance()
            // console.log("bal:", bal.toString())
            // console.log("updatedBal:", updatedBal.toString())
            assert.isAbove(updatedBal, bal)
          })
        })
        describe("viewPortionAt", function () {
          it("returns amount of times that users totalStaked goes into vaultAssetBalance at given week", async function () {
            const value = await vault.viewPortionAt(0, whale.address)
            // console.log(value.toString())
            // console.log(value[0] / 2 ** 64)
            //assert.equal(value[0])
          })
        })
        // describe("viewCurrentPeriod", function () {
        //   it("returns what week the contract is currently at", async function () {
        //     let week = 1
        //     const value = await vault.viewCurrentPeriod()
        //     console.log("value:", value.toString())
        //     console.log("week:", week)
        //     assert.equal(week, value)
        //     week++
        //   })
        // })
        describe("viewRewards", function () {
          it("returns amount of rewards a user earns", async function () {
            const value = await vault.viewRewards(whale.address)
            console.log(value.toString())
            const convertedAmount = value[0].toString().slice(0, -18)
            console.log("converted:", convertedAmount)
            console.log(value[0] >= 249)
            assert.isTrue(value[0] >= 249)
          })
        })
        describe("viewRewardInfo", function () {
          it("returns the rewardInfo for given week", async function () {
            const value = await vault.viewRewardInfo(0)
            assert.isTrue(999999999999999999999 >= value[0])
          })
        })
        describe("viewStakedBalance", function () {
          it("view the stablecoin balances of users", async function () {
            const value = await vault.viewStakedBalance(whale.address, 1)
            assert.equal(value, 5e10)
          })
        })
        describe("viewTotalStakedBalance", function () {
          it("view total amount a user has staked", async function () {
            const value = await vault.viewStakedBalance(whale.address, 1)
            assert.equal(value, 5e10)
          })
        })
        describe("viewLastClaimed", function () {
          it("returns the last week a user has claimed", async function () {
            const currentWeek = await vault.viewCurrentPeriod()
            const value = await vault.viewLastClaimed(whale.address)
            console.log(value)
            assert.equal(value, Number(currentWeek) - 1)
          })
        })
        describe("viewClaimedAmount", function () {
          it("returns the amount a user has claimed", async function () {
            const value = await vault.viewClaimedAmount(whale.address)
            const totalClaimed = await vault.viewTotalClaimed()
            assert.equal(value.toString(), totalClaimed)
          })
        })
        describe("viewTotalClaimed", function () {
          it("returns the totalClaimed variable", async function () {
            const value = await vault.viewTotalClaimed()
            const totalClaimed = await vault.viewClaimedAmount(whale.address)
            assert.equal(value.toString(), totalClaimed)
          })
        })
        describe("viewTotalStaked", function () {
          it("returns the totalStaked variable", async function () {
            const value = await vault.viewTotalStaked()
            console.log(value)
            const convertedAmount = value.toLocaleString("fullwide", {
              useGrouping: false,
            })
            assert.equal(convertedAmount, 50000000000000000000000)
          })
        })
        describe("viewUnoDeposit", function () {
          it("returns the amount of STBT that Uno Re has deposited into the vault", async function () {
            const value = await vault.viewUnoDeposit()
            console.log(value)
            const convertedAmount = value.toLocaleString("fullwide", {
              useGrouping: false,
            })
            assert.equal(convertedAmount, 200000000000000000000000)
          })
        })
        describe("viewStartingtime", function () {
          it("returns the vault's starting timestamp", async function () {
            const value = await vault.viewStartingtime()
            const lastUpkeep = await vault.viewLastUpkeepTime()
            assert.isBelow(value, lastUpkeep)
          })
        })
        describe("viewLastUpkeepTime", function () {
          it("returns the last time this contract had upkeep performed", async function () {
            const value = await vault.viewLastUpkeepTime()
            const startingTime = await vault.viewStartingtime()
            assert.isAbove(value, startingTime)
          })
        })
        describe("viewInterval", function () {
          it("returns the seconds in each rewards period", async function () {
            const value = await vault.viewInterval()
            assert.equal(value, 86400)
          })
        })
        describe("viewUnaccountedRewards", function () {
          it("returns the amount of rewards that can be claimed by uno", async function () {
            const value = await vault.viewUnaccountedRewards()
            await vault.connect(sWhale).unoClaim()
            const updatedValue = await vault.viewUnaccountedRewards()
            // console.log(value.toString())
            // console.log(updatedValue.toString())
            assert.isAbove(value, updatedValue)
          })
        })
        describe("viewStakeConversionRate", function () {
          it("returns the current stake STBT / stablecoin conversion", async function () {
            const value = await vault.viewStakeConversionRate()
            const unstakeValue = await vault.viewUnstakeConversionRate()
            const number =
              (Number(value) / 2 ** 64) * (Number(unstakeValue) / 2 ** 64)
            //console.log(number.toString())
            assert.approximately(number, 1, 0.5)
          })
        })
        describe("viewUnstakeConversionRate", function () {
          it("returns the current unstake STBT / stablecoin conversion", async function () {
            const value = await vault.viewUnstakeConversionRate()
            const stakeValue = await vault.viewStakeConversionRate()
            const number =
              (Number(value) / 2 ** 64) * (Number(stakeValue) / 2 ** 64)
            //console.log(number.toString())
            assert.approximately(number, 1, 0.5)
          })
        })
        describe("unstake", function () {
          // it("reverts if `amount` input is zero", async function () {
          //   await expect(
          //     vault.connect(whale).unstake(0, 1, 99, { gasLimit: 300000 })
          //   ).to.be.revertedWithCustomError(vault, "MatrixUno__ZeroAmountGiven")
          // })
          // it("reverts if `token` input is more than two", async function () {
          //   await expect(
          //     vault.connect(whale).stake(777, 3, 99, { gasLimit: 300000 })
          //   ).to.be.revertedWithCustomError(vault, "MatrixUno__InvalidTokenId")
          // })
          it("transferFrom takes xUNO from user and stores it", async function () {
            // To simulate the `claim` function call earning rewards,
            // I will transfer 1000 STBT from the STBT whale to the vault
            const initialVaultShares = await vault.balanceOf(vault.target)
            const initialVaultAssets = await stbt.balanceOf(vault.target)
            const xUnoDeposit = ethers.parseUnits("50000", 18)
            const initialVaultAllowance = await vault.allowance(
              whale.address,
              vault.target
            )
            const currentWeek = await vault.viewCurrentPeriod()
            const rewardInfo = await vault.viewRewardInfo(
              Number(currentWeek) - 1
            )
            const rewards = rewardInfo.rewards
            console.log("initial vault shares:", initialVaultShares.toString())
            console.log("initial vault assets:", initialVaultAssets.toString())
            console.log(
              "initial vault allowance:",
              initialVaultAllowance.toString()
            )
            console.log("rewards:", rewards.toString())
            const whaleBalance = await vault.viewStakedBalance(whale.address, 1)
            const whaleShares = await vault.balanceOf(whale.address)
            console.log("whaleShares:", whaleShares.toString())
            const totalClaimed = await vault.viewTotalClaimed()
            console.log("totalClaimed:", totalClaimed.toString())
            console.log("approve:", initialVaultAllowance < xUnoDeposit)
            if (initialVaultAllowance < xUnoDeposit) {
              const approveAmount =
                Number(xUnoDeposit) - Number(initialVaultAllowance)

              console.log("approveAmount:", approveAmount.toString())
              const convertedAmount = approveAmount.toLocaleString("fullwide", {
                useGrouping: false,
              })
              console.log("string amount:", convertedAmount)
              await vault.connect(whale).approve(vault.target, convertedAmount)
              console.log("approved!")
            }
            const vaultAllowance = await vault.allowance(
              whale.address,
              vault.target
            )
            console.log("vaultAllowance:", vaultAllowance.toString())
            console.log("whale vault balance:", whaleBalance.toString())
            console.log(
              "currentWeek:",
              (await vault.viewCurrentPeriod()).toString()
            )
            //if (whaleBalance > 100000000 && totalClaimed == 0) {
            const unstakeTx = await vault
              .connect(whale)
              .unstake(whaleShares, 1, 99, { gasLimit: 3000000 })
            await unstakeTx.wait(1)
            console.log("unstaked!")
            //}
            // mock rewards sent, now time to test claiming to see if rewards are calculated correctly
            const finalVaultShares = await vault.balanceOf(vault.target)
            const finalVaultAssets = await stbt.balanceOf(vault.target)
            const finalWhaleVaultBalance = await vault.viewStakedBalance(
              whale.address,
              1
            )
            const finalTotalClaimed = await vault.viewTotalClaimed()
            console.log("final vault shares:  ", finalVaultShares.toString())
            console.log("final vault assets:", finalVaultAssets.toString())
            console.log(
              "final whale vbalance:",
              finalWhaleVaultBalance.toString()
            )
            console.log("total assets claimed:", finalTotalClaimed.toString())
          })
          // it("user stablecoin balance is updated", async function () {
          //   // console.log("initial usdc bal:", initialUsdcBal.toString())
          //   // const updatedUsdcBal = await usdc.balanceOf(whale.address)
          //   // console.log("updated usdc bal:", updatedUsdcBal.toString())
          // })
          // it("vault exchanges stbt for stablecoin", async function () {})
          // it("vault transfers stablecoin to user", async function () {})
          // it("emits the `stablesClaimed` event", async function () {})
        })
      })
})
