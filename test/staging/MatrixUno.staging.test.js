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
 * 2. call unstake with 50,000 xUNO an ensure that 50,500 USDC is sent to the user
 * 2000 STBT needs to be sent to vault and 500 USDC needs to be sent to the mock curve pool prior to unstake
 *
 */

developmentChains.includes(network.name)
  ? describe.skip
  : describe("Matrix Uno Goerli Staging tests", function () {
      let deployer, stbt, usdc, vault
      beforeEach(async function () {
        deployer = (await getNamedAccounts()).deployer
        stbt = await ethers.getContractAt(
          stbtAbi,
          "0x0f539454d2Effd45E9bFeD7C57B2D48bFd04CB32"
        )
        usdc = await ethers.getContractAt(
          usdcAbi,
          "0x43c7181e745Be7265EB103c5D69F1b7b4EF8763f"
        )
        vault = await ethers.getContract("MatrixUno")
        console.log(vault.address)
        /** PRELIMINARY CONSOLE LOGS */
        //console.log(vault.address)
      })
      /**
       * 0. Deposit 200,000 STBT with the vault contract
       * 1. send 500 USDC to the mock curve pool <--- used STBT bot to send 1 million USDC
       * 2. approve vault to take usdc
       * 3. call stake()
       * 4. send 2000 STBT to the vault
       * 5. approve vault to take xUNO
       * 6. call unstake()
       * 7. Ensure the user gained USDC rewards
       */
      describe.only("stake", function () {
        it("initial STBT deposit mints 200,000 xUNO", async function () {
          const initialVaultShares = await vault.balanceOf(vault.address)
          console.log("InitialVaultShares:", initialVaultShares.toString())
          const stbtDeposit = ethers.utils.parseUnits("200000", 18)
          const initialStbtAllowance = await stbt.allowance(
            deployer,
            vault.address
          )
          console.log("initialSTBTAllowance:", initialStbtAllowance.toString())
          /** APPROVE VAULT TO TAKE STBT */
          if (initialStbtAllowance < stbtDeposit) {
            await stbt.approve(vault.address, stbtDeposit)
          }
          /** DEPOSIT THE STBT */
          console.log("reached")
          if (initialVaultShares == 0) {
            const depositTx = await vault.deposit(stbtDeposit, vault.address, {
              gasLimit: 3000000,
            })
            await depositTx.wait(1)
          }
          console.log("reached2")
          const finalVaultShares = await vault.balanceOf(vault.address)
          console.log("FinalVaultShares:", finalVaultShares.toString())
        })
        it("allows users to stake stablecoins for xUNO", async function () {
          const initialShares = await vault.balanceOf(deployer)
          const initialUsdcBal = await usdc.balanceOf(deployer)
          const initialAssets = await stbt.balanceOf(deployer)
          const initialAllowance = await usdc.allowance(deployer, vault.address)
          console.log("InitialUserShares:", initialShares.toString())
          console.log("InitialUserUsdc:", initialUsdcBal.toString())
          console.log("InitialUserAssets:", initialAssets.toString())
          console.log("InitialAllowance:", initialAllowance.toString())
          console.log("User:", deployer)
          /** APPROVE VAULT TO TAKE 50,000 USDC */
          if (initialAllowance < 5e10) {
            await usdc.approve(vault.address, 5e10)
          }
          console.log("approved!")
          /** CALL STAKE WITH 50,000 USDC IF USER HAS NO SHARES */
          if (initialShares == 0) {
            const stakeTx = await vault.stake(5e10, 1, 99, {
              gasLimit: 300000,
            })
            await stakeTx.wait(1)
            console.log("staked!")
          }

          const finalShares = await vault.balanceOf(deployer)
          const finalAssets = await stbt.balanceOf(deployer)

          console.log("FinalUserShares:", finalShares.toString())
          console.log("FinalUserAssets:", finalAssets.toString())
        })
      })
      describe.only("performUpkeep", function () {
        it("MOCK SENDING REWARDS", async function () {
          const initialShares = await vault.balanceOf(deployer)
          const initialVaultAssets = await stbt.balanceOf(vault.address)
          console.log("InitialShares:", initialShares.toString())
          console.log("InitialVaultAssets:", initialVaultAssets.toString())
          const stbtTransfer = ethers.utils.parseUnits("2000", 18)
          const stbtDeposit = ethers.utils.parseUnits("200000", 18)
          console.log((initialVaultAssets - stbtDeposit).toString())
          if (initialShares != 0 && initialVaultAssets <= stbtDeposit) {
            const transferTx = await stbt.transfer(vault.address, stbtTransfer)
            await transferTx.wait(1)
            console.log("Mock rewards distributed!")
          }
        })
        it("updates the rewardInfoArray", async function () {
          const initialInfo = await vault.viewRewardInfo(0)
          const returnVal = await vault.checkUpkeep("0x")
          console.log(initialInfo.toString())
          console.log("upkeepNeeded:", returnVal.upkeepNeeded)
          if (returnVal.upkeepNeeded == true) {
            await vault.performUpkeep("0x")
            console.log("upkeep performed!")
          } else {
            console.log("upkeep not needed!")
          }
          const finalInfo = await vault.viewRewardInfo(0)
          console.log(finalInfo.toString())
        })
      })
      describe.only("unstake", function () {
        it("allows users to unstake xUNO for their initial stablecoin deposit plus rewards earned", async function () {
          const initialShares = await vault.balanceOf(deployer)
          const initialVaultAssets = await stbt.balanceOf(vault.address)
          console.log("InitialShares:", initialShares.toString())
          console.log("InitialVaultAssets:", initialVaultAssets.toString())
          const stbtTransfer = ethers.utils.parseUnits("2000", 18)
          const stbtDeposit = ethers.utils.parseUnits("200000", 18)
          const xUnoTransfer = ethers.utils.parseUnits("50000", 18)
          console.log((initialVaultAssets - stbtDeposit).toString())
          // if (initialShares != 0 && initialVaultAssets <= stbtDeposit) {
          //   const transferTx = await stbt.transfer(vault.address, stbtTransfer)
          //   await transferTx.wait(1)
          // }
          const initialAllowance = await vault.allowance(
            deployer,
            vault.address
          )
          console.log("InitialAllowance:", initialAllowance.toString())
          if (initialAllowance < xUnoTransfer) {
            const approveTx = await vault.approve(vault.address, xUnoTransfer)
            await approveTx.wait(3)
            console.log("approved!")
          }
          console.log(
            initialVaultAssets > stbtDeposit && initialAllowance >= xUnoTransfer
          )
          if (
            initialVaultAssets > stbtDeposit &&
            initialAllowance >= xUnoTransfer
          ) {
            const unstakeTx = await vault.unstake(xUnoTransfer, 1, 99, {
              gasLimit: 3000000,
            })
            await unstakeTx.wait(1)
            console.log("unstaked!")
          }
          const rewards = await vault.viewTotalClaimed()
          console.log("totalClaimed:", rewards.toString())
        })
      })
    })
