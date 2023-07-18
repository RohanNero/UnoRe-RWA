const { network, ethers, getNamedAccounts } = require("hardhat")
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
      let deployer, stbt, usdc, vault, user, user2, usdt, dai
      beforeEach(async function () {
        ;[deployer, user, user2] = await ethers.getSigners()
        //deployer = (await getNamedAccounts()).deployer
        //{ deployer, user } = await getNamedAccounts();
        console.log("user:", user.address)
        stbt = await ethers.getContractAt(
          stbtAbi,
          "0x0f539454d2Effd45E9bFeD7C57B2D48bFd04CB32"
        )
        usdc = await ethers.getContractAt(
          usdcAbi,
          "0x43c7181e745Be7265EB103c5D69F1b7b4EF8763f"
        )
        vault = await ethers.getContract("MatrixUno")
        usdt = await ethers.getContract("MockUSDT")
        dai = await ethers.getContract("MockDAI")
        console.log("vault:", vault.address)
        console.log("dai:", dai.address)
        console.log("usdt:", usdt.address)
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
      describe("stake", function () {
        it("initial STBT deposit mints 200,000 xUNO", async function () {
          const initialVaultShares = await vault.balanceOf(vault.address)
          console.log("InitialVaultShares:", initialVaultShares.toString())
          const stbtDeposit = ethers.utils.parseUnits("200000", 18)
          const initialStbtAllowance = await stbt.allowance(
            deployer.address,
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
        it("allows users to stake DAI for xUNO", async function () {
          const initialShares = await vault.balanceOf(user.address)
          const initialDaiBal = await dai.balanceOf(user.address)
          const initialAssets = await stbt.balanceOf(user.address)
          const initialAllowance = await dai.allowance(
            user.address,
            vault.address
          )
          const daiDeposit = ethers.utils.parseUnits("50000", 18)
          console.log("InitialUserShares:", initialShares.toString())
          console.log("InitialUserUsdc:", initialDaiBal.toString())
          console.log("InitialUserAssets:", initialAssets.toString())
          console.log("InitialAllowance:", initialAllowance.toString())
          console.log("User:", user.address)
          /** APPROVE VAULT TO TAKE 50,000 DAI */
          if (initialAllowance < daiDeposit) {
            await dai.connect(user).approve(vault.address, daiDeposit)
          }
          console.log("approved!")
          /** CALL STAKE WITH 50,000 DAI IF USER HAS NO SHARES */
          if (initialShares == 0) {
            const stakeTx = await vault.connect(user).stake(daiDeposit, 0, 99, {
              gasLimit: 300000,
            })
            await stakeTx.wait(1)
            console.log("staked!")
          }

          const finalShares = await vault.balanceOf(user.address)
          const finalAssets = await stbt.balanceOf(user.address)

          console.log("FinalUserShares:", finalShares.toString())
          console.log("FinalUserAssets:", finalAssets.toString())
        })
        it("allows users to stake USDC for xUNO", async function () {
          const initialShares = await vault.balanceOf(deployer.address)
          const initialUsdcBal = await usdc.balanceOf(deployer.address)
          const initialAssets = await stbt.balanceOf(deployer.address)
          const initialAllowance = await usdc.allowance(
            deployer.address,
            vault.address
          )
          console.log("InitialUserShares:", initialShares.toString())
          console.log("InitialUserUsdc:", initialUsdcBal.toString())
          console.log("InitialUserAssets:", initialAssets.toString())
          console.log("InitialAllowance:", initialAllowance.toString())
          console.log("User:", deployer.address)
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

          const finalShares = await vault.balanceOf(deployer.address)
          const finalAssets = await stbt.balanceOf(deployer.address)

          console.log("FinalUserShares:", finalShares.toString())
          console.log("FinalUserAssets:", finalAssets.toString())
        })
        it("allows users to stake usdt for xUNO", async function () {
          const initialShares = await vault.balanceOf(user2.address)
          const initialUsdtBal = await usdt.balanceOf(user2.address)
          const initialAssets = await stbt.balanceOf(user2.address)
          const initialAllowance = await usdt.allowance(
            user2.address,
            vault.address
          )
          const usdtDeposit = ethers.utils.parseUnits("50000", 6)
          console.log("InitialUserShares:", initialShares.toString())
          console.log("InitialUserUsdc:", initialUsdtBal.toString())
          console.log("InitialUserAssets:", initialAssets.toString())
          console.log("InitialAllowance:", initialAllowance.toString())
          console.log("User:", user2.address)
          /** APPROVE VAULT TO TAKE 50,000 USDT */
          if (initialAllowance < 5e10) {
            await usdt.connect(user2).approve(vault.address, usdtDeposit)
          }
          console.log("approved!")
          /** CALL STAKE WITH 50,000 USDT IF USER HAS NO SHARES */
          if (initialShares == 0) {
            const stakeTx = await vault
              .connect(user2)
              .stake(usdtDeposit, 2, 99, {
                gasLimit: 300000,
              })
            await stakeTx.wait(1)
            console.log("staked!")
          }

          const finalShares = await vault.balanceOf(user2.address)
          const finalAssets = await stbt.balanceOf(user2.address)

          console.log("FinalUserShares:", finalShares.toString())
          console.log("FinalUserAssets:", finalAssets.toString())
        })
      })
      // describe("stake", function () {
      //   it("initial STBT deposit mints 200,000 xUNO", async function () {
      //     const initialVaultShares = await vault.balanceOf(vault.address)
      //     console.log("InitialVaultShares:", initialVaultShares.toString())
      //     const stbtDeposit = ethers.utils.parseUnits("200000", 18)
      //     const initialStbtAllowance = await stbt.allowance(
      //       deployer.address,
      //       vault.address
      //     )
      //     console.log("initialSTBTAllowance:", initialStbtAllowance.toString())
      //     /** APPROVE VAULT TO TAKE STBT */
      //     if (initialStbtAllowance < stbtDeposit) {
      //       await stbt.approve(vault.address, stbtDeposit)
      //     }
      //     /** DEPOSIT THE STBT */
      //     console.log("reached")
      //     if (initialVaultShares == 0) {
      //       const depositTx = await vault.deposit(stbtDeposit, vault.address, {
      //         gasLimit: 3000000,
      //       })
      //       await depositTx.wait(1)
      //     }
      //     console.log("reached2")
      //     const finalVaultShares = await vault.balanceOf(vault.address)
      //     console.log("FinalVaultShares:", finalVaultShares.toString())
      //   })
      //   it("allows users to stake stablecoins for xUNO", async function () {
      //     const initialShares = await vault.balanceOf(deployer.address)
      //     const initialUsdcBal = await usdc.balanceOf(deployer.address)
      //     const initialAssets = await stbt.balanceOf(deployer.address)
      //     const initialAllowance = await usdc.allowance(
      //       deployer.address,
      //       vault.address
      //     )
      //     console.log("InitialUserShares:", initialShares.toString())
      //     console.log("InitialUserUsdc:", initialUsdcBal.toString())
      //     console.log("InitialUserAssets:", initialAssets.toString())
      //     console.log("InitialAllowance:", initialAllowance.toString())
      //     console.log("User:", deployer.address)
      //     /** APPROVE VAULT TO TAKE 50,000 USDC */
      //     if (initialAllowance < 5e10) {
      //       await dai.approve(vault.address, 5e10)
      //     }
      //     console.log("approved!")
      //     /** CALL STAKE WITH 50,000 USDC IF USER HAS NO SHARES */
      //     if (initialShares == 0) {
      //       const stakeTx = await vault.stake(5e10, 1, 99, {
      //         gasLimit: 300000,
      //       })
      //       await stakeTx.wait(1)
      //       console.log("staked!")
      //     }

      //     const finalShares = await vault.balanceOf(deployer.address)
      //     const finalAssets = await stbt.balanceOf(deployer.address)

      //     console.log("FinalUserShares:", finalShares.toString())
      //     console.log("FinalUserAssets:", finalAssets.toString())
      //   })
      // })
      describe("performUpkeep", function () {
        it("MOCK SENDING REWARDS", async function () {
          const initialShares = await vault.balanceOf(deployer.address)
          const initialVaultAssets = await stbt.balanceOf(vault.address)
          console.log("InitialShares:", initialShares.toString())
          console.log("InitialVaultAssets:", initialVaultAssets.toString())
          const stbtTransfer = ethers.utils.parseUnits("2000", 18)
          const stbtDeposit = ethers.utils.parseUnits("200000", 18)
          console.log((initialVaultAssets - stbtDeposit).toString())
          //if (initialShares != 0 && initialVaultAssets <= stbtDeposit) {
          const transferTx = await stbt.transfer(vault.address, stbtTransfer)
          await transferTx.wait(1)
          console.log("Mock rewards distributed!")
          //}
        })
        // it("updates the rewardInfoArray", async function () {
        //   const initialInfo = await vault.viewRewardInfo(0)
        //   const returnVal = await vault.checkUpkeep("0x")
        //   console.log(initialInfo.toString())
        //   console.log("upkeepNeeded:", returnVal.upkeepNeeded)
        //   if (returnVal.upkeepNeeded == true) {
        //     const upkeep = await vault.performUpkeep("0x")
        //     await upkeep.wait(1)
        //     console.log("upkeep performed!")
        //   } else {
        //     console.log("upkeep not needed!")
        //   }
        //   const finalInfo = await vault.viewRewardInfo(0)
        //   console.log(finalInfo.toString())
        // })
      })
      describe("unstake", function () {
        it("allows users to unstake xUNO for their initial DAI deposit plus rewards earned", async function () {
          const initialShares = await vault.balanceOf(user.address)
          const initialVaultAssets = await stbt.balanceOf(vault.address)
          console.log("InitialShares:", initialShares.toString())
          console.log("InitialVaultAssets:", initialVaultAssets.toString())
          const stbtTransfer = ethers.utils.parseUnits("2000", 18)
          const stbtDeposit = ethers.utils.parseUnits("200000", 18)
          //const xUnoTransfer = ethers.utils.parseUnits("50000", 18)
          const xUnoTransfer = await vault.balanceOf(user.address)
          console.log((initialVaultAssets - stbtDeposit).toString())
          // if (initialShares != 0 && initialVaultAssets <= stbtDeposit) {
          //   const transferTx = await stbt.transfer(vault.address, stbtTransfer)
          //   await transferTx.wait(1)
          // }
          const initialAllowance = await vault.allowance(
            user.address,
            vault.address
          )
          console.log("InitialAllowance:", initialAllowance.toString())
          if (initialAllowance < xUnoTransfer) {
            const approveTx = await vault
              .connect(user)
              .approve(vault.address, xUnoTransfer)
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
            const unstakeTx = await vault
              .connect(user)
              .unstake(xUnoTransfer, 0, 99, {
                gasLimit: 3000000,
              })
            await unstakeTx.wait(1)
            console.log("unstaked!")
          }
          const rewards = await vault.viewTotalClaimed()
          console.log("totalClaimed:", rewards.toString())
        })
        it("allows users to unstake xUNO for their initial USDC deposit plus rewards earned", async function () {
          const initialShares = await vault.balanceOf(deployer.address)
          const initialVaultAssets = await stbt.balanceOf(vault.address)
          console.log("InitialShares:", initialShares.toString())
          console.log("InitialVaultAssets:", initialVaultAssets.toString())
          const stbtTransfer = ethers.utils.parseUnits("2000", 18)
          const stbtDeposit = ethers.utils.parseUnits("200000", 18)
          //const xUnoTransfer = ethers.utils.parseUnits("50000", 18)
          const xUnoTransfer = await vault.balanceOf(deployer.address)
          console.log((initialVaultAssets - stbtDeposit).toString())
          // if (initialShares != 0 && initialVaultAssets <= stbtDeposit) {
          //   const transferTx = await stbt.transfer(vault.address, stbtTransfer)
          //   await transferTx.wait(1)
          // }
          const initialAllowance = await vault.allowance(
            deployer.address,
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
        it("allows users to unstake xUNO for their initial USDT deposit plus rewards earned", async function () {
          const initialShares = await vault.balanceOf(user2.address)
          const initialVaultAssets = await stbt.balanceOf(vault.address)
          console.log("InitialShares:", initialShares.toString())
          console.log("InitialVaultAssets:", initialVaultAssets.toString())
          const stbtTransfer = ethers.utils.parseUnits("2000", 18)
          const stbtDeposit = ethers.utils.parseUnits("200000", 18)
          //const xUnoTransfer = ethers.utils.parseUnits("50000", 18)
          const xUnoTransfer = await vault.balanceOf(user2.address)
          console.log((initialVaultAssets - stbtDeposit).toString())
          // if (initialShares != 0 && initialVaultAssets <= stbtDeposit) {
          //   const transferTx = await stbt.transfer(vault.address, stbtTransfer)
          //   await transferTx.wait(1)
          // }
          const initialAllowance = await vault.allowance(
            user2.address,
            vault.address
          )
          console.log("InitialAllowance:", initialAllowance.toString())
          if (initialAllowance < xUnoTransfer) {
            const approveTx = await vault
              .connect(user2)
              .approve(vault.address, xUnoTransfer)
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
            const unstakeTx = await vault
              .connect(user2)
              .unstake(xUnoTransfer, 2, 99, {
                gasLimit: 3000000,
              })
            await unstakeTx.wait(1)
            console.log("unstaked!")
          }
          const rewards = await vault.viewTotalClaimed()
          console.log("totalClaimed:", rewards.toString())
        })
      })
      // describe("unstake", function () {
      //   it("allows users to unstake xUNO for their initial stablecoin deposit plus rewards earned", async function () {
      //     const initialShares = await vault.balanceOf(deployer.address)
      //     const initialVaultAssets = await stbt.balanceOf(vault.address)
      //     console.log("InitialShares:", initialShares.toString())
      //     console.log("InitialVaultAssets:", initialVaultAssets.toString())
      //     const stbtTransfer = ethers.utils.parseUnits("2000", 18)
      //     const stbtDeposit = ethers.utils.parseUnits("200000", 18)
      //     //const xUnoTransfer = ethers.utils.parseUnits("50000", 18)
      //     const xUnoTransfer = await vault.balanceOf(deployer.address)
      //     console.log((initialVaultAssets - stbtDeposit).toString())
      //     // if (initialShares != 0 && initialVaultAssets <= stbtDeposit) {
      //     //   const transferTx = await stbt.transfer(vault.address, stbtTransfer)
      //     //   await transferTx.wait(1)
      //     // }
      //     const initialAllowance = await vault.allowance(
      //       deployer.address,
      //       vault.address
      //     )
      //     console.log("InitialAllowance:", initialAllowance.toString())
      //     if (initialAllowance < xUnoTransfer) {
      //       const approveTx = await vault.approve(vault.address, xUnoTransfer)
      //       await approveTx.wait(3)
      //       console.log("approved!")
      //     }
      //     console.log(
      //       initialVaultAssets > stbtDeposit && initialAllowance >= xUnoTransfer
      //     )
      //     if (
      //       initialVaultAssets > stbtDeposit &&
      //       initialAllowance >= xUnoTransfer
      //     ) {
      //       const unstakeTx = await vault.unstake(xUnoTransfer, 1, 99, {
      //         gasLimit: 3000000,
      //       })
      //       await unstakeTx.wait(1)
      //       console.log("unstaked!")
      //     }
      //     const rewards = await vault.viewTotalClaimed()
      //     console.log("totalClaimed:", rewards.toString())
      //   })
      // })
      describe("deposit", function () {
        it("allows a user to deposit stbt for xUNO", async function () {
          const initialVaultShares = await vault.balanceOf(vault.address)
          console.log("InitialVaultShares:", initialVaultShares.toString())
          const stbtDeposit = ethers.utils.parseUnits("50000", 18)
          const initialStbtAllowance = await stbt.allowance(
            user.address,
            vault.address
          )
          console.log("initialSTBTAllowance:", initialStbtAllowance.toString())
          /** APPROVE VAULT TO TAKE STBT */
          if (initialStbtAllowance < stbtDeposit) {
            await stbt.connect(user).approve(vault.address, stbtDeposit)
          }
          /** DEPOSIT THE STBT */
          console.log("reached")
          const depositTx = await vault
            .connect(user)
            .deposit(stbtDeposit, user.address, {
              gasLimit: 3000000,
            })
          await depositTx.wait(1)
          console.log("deposited!")
          const finalVaultShares = await vault.balanceOf(vault.address)
          console.log("FinalVaultShares:", finalVaultShares.toString())
        })
      })
      describe("withdraw", function () {
        it("should allow user to withdraw their stbt and earn rewards", async function () {
          //const { user } = await getNamedAccounts()
          const initialShares = await vault.balanceOf(user.address)
          const initialVaultAssets = await stbt.balanceOf(vault.address)
          console.log("InitialShares:", initialShares.toString())
          console.log("InitialVaultAssets:", initialVaultAssets.toString())
          const stbtTransfer = ethers.utils.parseUnits("2000", 18)
          const stbtDeposit = ethers.utils.parseUnits("200000", 18)
          const xUnoTransfer = ethers.utils.parseUnits("50000", 18)
          //const xUnoTransfer = await vault.balanceOf(deployer)
          // console.log((initialVaultAssets - stbtDeposit).toString())
          const initialAllowance = await vault.allowance(
            user.address,
            vault.address
          )

          if (initialAllowance < xUnoTransfer) {
            const approveTx = await vault
              .connect(user)
              .approve(vault.address, xUnoTransfer)
            await approveTx.wait(3)
            console.log("approved!")
          }
          console.log("InitialAllowance:", initialAllowance.toString())
          const unstakeTx = await vault
            .connect(user)
            .withdraw(xUnoTransfer, user.address, user.address, {
              gasLimit: 3000000,
            })
          await unstakeTx.wait(1)
          console.log("withdrawn!")
          const rewards = await vault.viewTotalClaimed()
          console.log("totalClaimed:", rewards.toString())
          console.log(
            initialVaultAssets > stbtDeposit && initialAllowance >= xUnoTransfer
          )
        })
      })
    })
