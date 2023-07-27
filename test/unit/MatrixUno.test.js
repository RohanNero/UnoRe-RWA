const { network, ethers } = require("hardhat")
const hre = require("hardhat")
const { setCode, time } = require("@nomicfoundation/hardhat-network-helpers")
const {
  developmentChains,
  networkConfig,
  usdcAbi,
  usdtAbi,
  daiAbi,
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

describe.only("MatrixUno Unit Tests", function () {
  let deployer,
    usdcWhale,
    matrixUNO,
    loki,
    usdc,
    dai,
    usdt,
    lpToken,
    gauge,
    threeCRV,
    stableSwap,
    crv,
    minter,
    sWhale,
    stbt,
    stbtModerator,
    vault,
    stbtModeratorExecutor,
    stbtModeratorProposer,
    daiWhale,
    usdtWhale
  //initialUsdcBal
  beforeEach(async function () {
    ;[deployer] = await ethers.getSigners()
    //console.log(network)

    // USDC usdcWhale
    const provider = new ethers.providers.JsonRpcProvider(
      "http://localhost:8545"
    )
    // await provider.send("hardhat_impersonateAccount", [
    //   "0x171cda359aa49E46Dec45F375ad6c256fdFBD420",
    // ])
    usdcWhale = provider.getSigner("0x171cda359aa49E46Dec45F375ad6c256fdFBD420")
    daiWhale = provider.getSigner("0x604981db0C06Ea1b37495265EDa4619c8Eb95A3D")
    usdtWhale = provider.getSigner("0xDF1fC5523f2e5eA4f6DAc2eAEd3263953A391B0c")
    // This method kept throwing error messages from time to time so now he is green :p
    //whale = await ethers.getSigner("0x171cda359aa49E46Dec45F375ad6c256fdFBD420")
    //console.log(usdcWhale)
    // 0x51250e5292006aF94Ff286d52729b58aB78A0465 - alot of STBT but no ETH for tx gas
    sWhale = provider.getSigner("0x81BD585940501b583fD092BC8397F2119A96E5ba")
    // stbtModerator = provider.getSigner(
    //   "0x22276A1BD16bc3052b362C2e0f65aacE04ed6F99"
    // )
    stbtModeratorExecutor = provider.getSigner(
      "0xd32a1441872774f30EC9C453983cf5C95a720123"
    )
    stbtModeratorProposer = provider.getSigner(
      "0x65FF5a67D8d7292Bd4Ea7B6CD863D9F3ca14f046"
    )
    usdc = await ethers.getContractAt(
      usdcAbi,
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    )
    dai = await ethers.getContractAt(
      daiAbi,
      "0x6b175474e89094c44da98b954eedeac495271d0f"
    )
    usdt = await ethers.getContractAt(
      usdtAbi,
      "0xdac17f958d2ee523a2206206994597c13d831ec7"
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
    //initialUsdcBal = await usdc.balanceOf(usdcWhale._address)
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
            const initialBal = await stbt.balanceOf(sWhale._address, {
              gasLimit: 300000,
            })
            const string = initialBal.toString()
            const bal = string.slice(0, -18)
            // console.log("STBT usdcWhale address:", sWhale._address)
            // //console.log(stbt)
            // console.log("STBT balance:", initialBal.toString())
            // console.log("truncated balance:", bal)
            assert.isTrue(bal > 100000)
          })
          it("allow moderator to update the vault's STBT permissions", async function () {
            const prePermissions = await stbt.permissions(vault.address)

            // going to have to setPermission through `execute` function call...
            // await setCode(
            //   stbtModerator.address,
            //   "0x608060405234801561001057600080fd5b50610372806100206000396000f3fe608060405234801561001057600080fd5b506004361061002b5760003560e01c8063d8a8ab2514610030575b600080fd5b61004a600480360381019061004591906101d2565b61004c565b005b6000808473ffffffffffffffffffffffffffffffffffffffff168484604051610076929190610271565b6000604051808303816000865af19150503d80600081146100b3576040519150601f19603f3d011682016040523d82523d6000602084013e6100b8565b606091505b5091509150816100c757600080fd5b7f30f9fb0901262acb38d8b44b67a477c64631865c967e8d3dbd8ad1273432981d816040516100f6919061031a565b60405180910390a15050505050565b600080fd5b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b600061013a8261010f565b9050919050565b61014a8161012f565b811461015557600080fd5b50565b60008135905061016781610141565b92915050565b600080fd5b600080fd5b600080fd5b60008083601f8401126101925761019161016d565b5b8235905067ffffffffffffffff8111156101af576101ae610172565b5b6020830191508360018202830111156101cb576101ca610177565b5b9250929050565b6000806000604084860312156101eb576101ea610105565b5b60006101f986828701610158565b935050602084013567ffffffffffffffff81111561021a5761021961010a565b5b6102268682870161017c565b92509250509250925092565b600081905092915050565b82818337600083830152505050565b60006102588385610232565b935061026583858461023d565b82840190509392505050565b600061027e82848661024c565b91508190509392505050565b600081519050919050565b600082825260208201905092915050565b60005b838110156102c45780820151818401526020810190506102a9565b60008484015250505050565b6000601f19601f8301169050919050565b60006102ec8261028a565b6102f68185610295565b93506103068185602086016102a6565b61030f816102d0565b840191505092915050565b6000602082019050818103600083015261033481846102e1565b90509291505056fea26469706673582212204acf0e1b8d45b284956a8ddbd9db87ef90d565d7cb41cff807253b75ce82018064736f6c63430008120033"
            // )

            // const provider = new ethers.providers.JsonRpcProvider(
            //   "http://localhost:8545"
            // )
            if (prePermissions[0] == false) {
              await hre.network.provider.request({
                method: "hardhat_impersonateAccount",
                params: [stbtModeratorProposer._address],
              })
              // Moderator arguments: address target,uint256 value,bytes calldata data,bytes32 predecessor,bytes32 salt,uint256 delay
              await stbtModerator
                .connect(stbtModeratorProposer)
                .schedule(
                  stbt.address,
                  0,
                  "0x47e640c000000000000000000000000097fd63d049089cd70d9d139ccf9338c81372de68000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000",
                  "0x0000000000000000000000000000000000000000000000000000000000000000",
                  "0x3235363030376561343437613862653633303530396531623764396132326335",
                  0,
                  { gasLimit: 300000 }
                )
              await hre.network.provider.request({
                method: "hardhat_impersonateAccount",
                params: [stbtModeratorExecutor._address],
              })
              await stbtModerator
                .connect(stbtModeratorExecutor)
                .execute(
                  stbt.address,
                  0,
                  "0x47e640c000000000000000000000000097fd63d049089cd70d9d139ccf9338c81372de68000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000",
                  "0x0000000000000000000000000000000000000000000000000000000000000000",
                  "0x3235363030376561343437613862653633303530396531623764396132326335"
                )
            }

            //console.log(stbtModerator.functions)
            //await stbtModerator.eggs(vault.address, [true, true, 0])
            // original function call
            // await stbt
            //   .connect(stbtModerator)
            //   .setPermission(vault.address, [true, true, 0])
            const postPermissions = await stbt.permissions(vault.address)
            const moderator = await stbt.moderator()
            // console.log(prePermissions.toString())
            // console.log(postPermissions.toString())
            // console.log("vault address:", vault.address)
            // console.log("moderator:", moderator)
            // console.log("impersona:", stbtModerator.address)
            //console.log(stbt.functions)
            //assert.isTrue(postPermissions[1])
          })
          it("STBT whale should be able to deposit STBT", async function () {
            await hre.network.provider.request({
              method: "hardhat_impersonateAccount",
              params: [sWhale._address],
            })
            const stbtBalance = await stbt.balanceOf(sWhale._address)
            const stbtAllowance = await stbt.allowance(
              sWhale._address,
              vault.address
            )
            const stbtDeposit = ethers.utils.parseUnits("200000", 18)
            const vaultStbtBalance = await stbt.balanceOf(vault.address)
            // console.log("stbt Balance:", stbtBalance.toString())
            // console.log("stbt Deposit:", stbtDeposit.toString())
            // console.log("stbt Allowance:", stbtAllowance.toString())
            // console.log("vault stbt balance:", vaultStbtBalance.toString())
            if (stbtAllowance.toString() < stbtDeposit.toString()) {
              await stbt.connect(sWhale).approve(vault.address, stbtDeposit, {
                gasLimit: 700000,
              })
              //console.log(stbtDeposit.toString(), "STBT approved!")
            }
            if (vaultStbtBalance < stbtDeposit / 2) {
              await vault.connect(sWhale).deposit(stbtDeposit, vault.address, {
                gasLimit: 700000,
              })
            }
            const endingVaultStbtBalance = await stbt.balanceOf(vault.address)
            //console.log(endingVaultStbtBalance.toString())
            assert.isTrue(endingVaultStbtBalance >= stbtDeposit / 2)
          })
          it("vault should mint and hold xUNO after the STBT deposit", async function () {
            const vaultSharesBalance = await vault.balanceOf(vault.address)
            const vaultSharesBalanceSliced = vaultSharesBalance
              .toString()
              .slice(0, -18)
            //console.log(vaultSharesBalanceSliced)
            // assert.isTrue(vaultSharesBalanceSliced >= 99999)
          })
          // Actual MatrixUno `stake()` function calls
          it("reverts if `amount` input is zero", async function () {
            await hre.network.provider.request({
              method: "hardhat_impersonateAccount",
              params: [usdcWhale._address],
            })
            await expect(
              vault.connect(usdcWhale).stake(0, 1, 99, { gasLimit: 300000 })
            ).to.be.revertedWithCustomError(vault, "MatrixUno__ZeroAmountGiven")
          })
          it("reverts if `token` input is more than two", async function () {
            await expect(
              vault.connect(usdcWhale).stake(777, 3, 99, { gasLimit: 300000 })
            ).to.be.revertedWithCustomError(vault, "MatrixUno__InvalidTokenId")
          })
          // The important one DAI
          it("transfers the dai from user to vault", async function () {
            await hre.network.provider.request({
              method: "hardhat_impersonateAccount",
              params: [daiWhale._address],
            })
            const initialVaultdaiBalance = await dai.balanceOf(vault.address)
            const daiBalance = await dai.balanceOf(daiWhale._address)
            const daiAllowance = await dai.allowance(
              daiWhale._address,
              vault.address
            )
            const daiDeposit = ethers.utils.parseUnits("50000", 18)
            console.log("daiWhale dai balance:", daiBalance.toString())
            console.log("vault dai allowance:", daiAllowance.toString())
            console.log(
              "initial vault dai balance:",
              initialVaultdaiBalance.toString()
            )
            //if (daiAllowance < daiDeposit) {
            await dai
              .connect(daiWhale)
              .approve(vault.address, daiDeposit.toString())
            //}
            const updateddaiAllowance = await dai.allowance(
              daiWhale._address,
              vault.address
            )
            const totalClaimed = await vault.viewTotalClaimed()
            console.log(
              "updated dai allowance:",
              updateddaiAllowance.toString()
            )
            console.log("total claimed:", totalClaimed.toString())
            console.log((await vault.balanceOf(vault.address)).toString())
            console.log("daiDeposit:", daiDeposit.toString())
            //if (initialVaultdaiBalance < daiDeposit) {
            const shares = await vault
              .connect(daiWhale)
              .stake(daiDeposit, 0, 99, { gasLimit: 700000 })
            //}
            //console.log("staked!")

            const finalVaultdaiBalance = await dai.balanceOf(vault.address)
            //console.log("final vault dai balance:", finalVaultdaiBalance.toString())
          })
          it("updates the user's balance for the staked dai", async function () {
            const vaultBalance = await vault.viewBalance(daiWhale._address, 0)
            const totalClaimed = await vault.viewTotalClaimed()
            console.log("daiWhale dai balance:", vaultBalance.toString())
            console.log("total claimed:", totalClaimed.toString())
            // eventually need to make > into = since unstake should be working properly
            assert.isTrue(vaultBalance >= 50000000000 || totalClaimed > 0)
          })
          it("transfers xUNO to the user", async function () {
            const daiWhalexUnoBalance = await vault.balanceOf(daiWhale._address)
            const vaultxUnoBalance = await vault.balanceOf(vault.address)
            const vaultSymbol = await vault.symbol()
            const sliceddaiWhaleBalance = daiWhalexUnoBalance
              .toString()
              .slice(0, -18)
            const totalClaimed = await vault.viewTotalClaimed()
            console.log(
              "daiWhale xUNO balance:",
              daiWhalexUnoBalance.toString()
            )
            console.log("vault xUNO balance:", vaultxUnoBalance.toString())
            console.log("vault shares symbol:", vaultSymbol.toString())
            console.log("total claimed:", totalClaimed.toString())
            assert.isTrue(sliceddaiWhaleBalance > 1000 || totalClaimed > 0)
          })
          // The important one USDC
          it("transfers the usdc from user to vault", async function () {
            const initialVaultUsdcBalance = await usdc.balanceOf(vault.address)
            const usdcBalance = await usdc.balanceOf(usdcWhale._address)
            const usdcAllowance = await usdc.allowance(
              usdcWhale._address,
              vault.address
            )
            const usdcDeposit = 50000 * 1e6
            // console.log("whale usdc balance:", usdcBalance.toString())
            // console.log("vault usdc allowance:", usdcAllowance.toString())
            // console.log(
            //   "initial vault usdc balance:",
            //   initialVaultUsdcBalance.toString()
            // )
            //if (usdcAllowance < usdcDeposit) {
            await usdc
              .connect(usdcWhale)
              .approve(vault.address, usdcDeposit.toString())
            //}
            const updatedUsdcAllowance = await usdc.allowance(
              usdcWhale._address,
              vault.address
            )
            const totalClaimed = await vault.viewTotalClaimed()
            // console.log("updated usdc allowance:", updatedUsdcAllowance.toString())
            // console.log("total claimed:", totalClaimed.toString())
            // console.log((await vault.balanceOf(vault.address)).toString())
            // console.log("usdcDeposit:",usdcDeposit.toString())
            //if (initialVaultUsdcBalance < usdcDeposit) {
            const shares = await vault
              .connect(usdcWhale)
              .stake(usdcDeposit, 1, 99, { gasLimit: 700000 })
            //}
            //console.log("staked!")

            const finalVaultUsdcBalance = await usdc.balanceOf(vault.address)
            //console.log("final vault usdc balance:", finalVaultUsdcBalance.toString())
          })
          it("updates the user's balance for the staked usdc", async function () {
            const vaultBalance = await vault.viewBalance(usdcWhale._address, 1)
            const totalClaimed = await vault.viewTotalClaimed()
            //console.log("whale usdc balance:", vaultBalance.toString())
            //console.log("total claimed:", totalClaimed.toString())
            // eventually need to make > into = since unstake should be working properly
            assert.isTrue(vaultBalance >= 50000000000 || totalClaimed > 0)
          })
          it("transfers xUNO to the user", async function () {
            const usdcWhalexUnoBalance = await vault.balanceOf(
              usdcWhale._address
            )
            const vaultxUnoBalance = await vault.balanceOf(vault.address)
            const vaultSymbol = await vault.symbol()
            const slicedWhaleBalance = usdcWhalexUnoBalance
              .toString()
              .slice(0, -18)
            const totalClaimed = await vault.viewTotalClaimed()
            console.log("whale xUNO balance:", usdcWhalexUnoBalance.toString())
            console.log("vault xUNO balance:", vaultxUnoBalance.toString())
            console.log("vault shares symbol:", vaultSymbol.toString())
            console.log("total claimed:", totalClaimed.toString())
            assert.isTrue(slicedWhaleBalance > 1000 || totalClaimed > 0)
          })
          // The important one USDT
          it("transfers the usdt from user to vault", async function () {
            await hre.network.provider.request({
              method: "hardhat_impersonateAccount",
              params: [usdtWhale._address],
            })
            const initialVaultusdtBalance = await usdt.balanceOf(vault.address)
            const usdtBalance = await usdt.balanceOf(usdtWhale._address)
            const usdtAllowance = await usdt.allowance(
              usdtWhale._address,
              vault.address
            )
            const usdtDeposit = 50000 * 1e6
            console.log("whale usdt balance:", usdtBalance.toString())
            console.log("vault usdt allowance:", usdtAllowance.toString())
            console.log(
              "initial vault usdt balance:",
              initialVaultusdtBalance.toString()
            )
            //if (usdtAllowance < usdtDeposit) {
            await usdt
              .connect(usdtWhale)
              .approve(vault.address, usdtDeposit.toString(), {
                gasLimit: 300000,
              })
            //}
            const updatedusdtAllowance = await usdt.allowance(
              usdtWhale._address,
              vault.address
            )
            const totalClaimed = await vault.viewTotalClaimed()
            console.log(
              "updated usdt allowance:",
              updatedusdtAllowance.toString()
            )
            console.log("total claimed:", totalClaimed.toString())
            console.log(
              "vault xUNO:",
              (await vault.balanceOf(vault.address)).toString()
            )
            console.log("usdtDeposit:", usdtDeposit.toString())
            //if (initialVaultusdtBalance < usdtDeposit) {
            const shares = await vault
              .connect(usdtWhale)
              .stake(usdtDeposit, 2, 99, { gasLimit: 700000 })
            //}
            console.log("staked!")

            const finalVaultusdtBalance = await usdt.balanceOf(vault.address)
            //console.log("final vault usdt balance:", finalVaultusdtBalance.toString())
          })
          it("updates the user's balance for the staked usdt", async function () {
            const vaultBalance = await vault.viewBalance(usdtWhale._address, 2)
            const totalClaimed = await vault.viewTotalClaimed()
            //console.log("whale usdc balance:", vaultBalance.toString())
            //console.log("total claimed:", totalClaimed.toString())
            // eventually need to make > into = since unstake should be working properly
            assert.isTrue(vaultBalance >= 50000000000 || totalClaimed > 0)
          })
          it("transfers xUNO to the user", async function () {
            const usdcWhalexUnoBalance = await vault.balanceOf(
              usdtWhale._address
            )
            const vaultxUnoBalance = await vault.balanceOf(vault.address)
            const vaultSymbol = await vault.symbol()
            const slicedWhaleBalance = usdcWhalexUnoBalance
              .toString()
              .slice(0, -18)
            const totalClaimed = await vault.viewTotalClaimed()
            console.log("whale xUNO balance:", usdcWhalexUnoBalance.toString())
            console.log("vault xUNO balance:", vaultxUnoBalance.toString())
            console.log("vault shares symbol:", vaultSymbol.toString())
            console.log("total claimed:", totalClaimed.toString())
            assert.isTrue(slicedWhaleBalance > 1000 || totalClaimed > 0)
          })
          // come back to this test later
          // it("`transferFromAmount` is less than provided `amount` if vault doesn't have enough xUNO", async function () {})
        })
        describe("performUpkeep", function () {
          it("MOCK SENDING REWARDS", async function () {
            const initialVaultAssets = await stbt.balanceOf(vault.address)
            const thousandStbt = ethers.utils.parseUnits("1000", 18)
            const slicedVaultAssets = initialVaultAssets
              .toString()
              .slice(0, -18)
            //if (slicedVaultAssets < 200000) {
            await stbt.connect(sWhale).transfer(vault.address, thousandStbt)
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

            const returnVal = await vault.checkUpkeep()
            console.log("upkeepNeeded:", returnVal)
            if (returnVal == false) {
              await time.increase(86400)
            }
            const perform = await vault.performUpkeep()
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
        describe("transfer", function () {
          it("should update user balances correctly", async function () {
            const ten = ethers.utils.parseUnits("10", 18)
            const initialBal = await vault.viewBalance(usdcWhale._address, 1)
            const initialxUNO = await vault.viewBalance(usdcWhale._address, 4)
            const initialRBal = await vault.viewBalance(sWhale._address, 1)
            console.log("initialRBal:", initialRBal.toString())
            console.log("intialBal:", initialBal.toString())
            console.log("initialXUNO:", initialxUNO.toString())
            await vault
              .connect(usdcWhale)
              .transfer(sWhale._address, ten, { gasLimit: 700000 })
            const updatedBal = await vault.viewBalance(usdcWhale._address, 1)
            const updatedRBal = await vault.viewBalance(sWhale._address, 1)
            console.log("updatedRBal:", updatedRBal.toString())
            console.log("updatedBal:", updatedBal.toString())
            // await vault.connect(sWhale).transfer(usdcWhale.address, ten)
            // const finalBal = await vault.viewBalance(usdcWhale.address, 1)
            // const finalRBal = await vault.viewBalance(sWhale.address, 1)
            // console.log("finalRBal:", finalRBal.toString())
            // console.log("finalBal:", finalBal.toString())
          })
        })
        describe("transferFrom", function () {
          it("should update user balances correctly", async function () {
            const ten = ethers.utils.parseUnits("10", 18)
            const initialBal = await vault.viewBalance(usdcWhale._address, 1)
            const initialRBal = await vault.viewBalance(sWhale._address, 1)
            console.log("initialRBal:", initialRBal.toString())
            console.log("intialBal:", initialBal.toString())
            await vault.connect(sWhale).approve(usdcWhale._address, ten)
            console.log("approved")
            await vault
              .connect(usdcWhale)
              .transferFrom(sWhale._address, usdcWhale._address, ten, {
                gasLimit: 700000,
              })
            const updatedBal = await vault.viewBalance(usdcWhale._address, 1)
            const updatedRBal = await vault.viewBalance(sWhale._address, 1)
            console.log("updatedRBal:", updatedRBal.toString())
            console.log("updatedBal:", updatedBal.toString())
          })
        })
        // describe.only("withdraw", function () {
        //   it("should allow uno to withdraw their initial deposit at any time", async function () {
        //     const uno = await vault.viewUnoAddress()
        //     console.log("uno:", uno.toString())
        //     console.log(sWhale._address)
        //     const initialShares = await vault.balanceOf(sWhale._address)
        //     const initialVaultAssets = await stbt.balanceOf(vault.address)
        //     console.log("InitialShares:", initialShares.toString())
        //     console.log("InitialVaultAssets:", initialVaultAssets.toString())
        //     const stbtDeposit = ethers.utils.parseUnits("200000", 18)
        //     // console.log((initialVaultAssets - stbtDeposit).toString())
        //     const initialAllowance = await vault.allowance(
        //       sWhale._address,
        //       vault.address
        //     )

        //     if (initialAllowance < stbtDeposit) {
        //       const approveTx = await vault
        //         .connect(sWhale)
        //         .approve(vault.address, stbtDeposit)
        //       console.log("approved!")
        //     }
        //     console.log("InitialAllowance:", initialAllowance.toString())
        //     const withdrawTx = await vault
        //       .connect(sWhale)
        //       .withdraw(stbtDeposit, sWhale._address, vault.address, {
        //         gasLimit: 7000000,
        //       })
        //     console.log("withdrawn!")
        //     const rewards = await vault.viewTotalClaimed()
        //     console.log("totalClaimed:", rewards.toString())
        //     // console.log(
        //     //   initialVaultAssets > stbtDeposit && initialAllowance >= xUnoTransfer
        //     // )
        //   })
        // })

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
            await usdc.connect(usdcWhale).transfer(vault.address, 777)
            const updatedBal = await vault.viewVaultStableBalance()
            // console.log("bal:", bal.toString())
            // console.log("updatedBal:", updatedBal.toString())
            assert.isAbove(updatedBal, bal)
          })
        })
        describe("viewPortionAt", function () {
          it("returns amount of times that users totalStaked goes into vaultAssetBalance at given week", async function () {
            const value = await vault.viewPortionAt(0, usdcWhale._address)
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
        // describe("viewRewards", function () {
        //   it("returns amount of rewards a user earns", async function () {
        //     const value = await vault.viewRewards(usdcWhale._address)
        //     console.log(value.toString())
        //     const convertedAmount = value[0].toString().slice(0, -18)
        //     console.log("converted:", convertedAmount)
        //     console.log(value[0] >= 249)
        //     assert.isTrue(value[0] >= 249)
        //   })
        //})
        describe("viewRewardInfo", function () {
          it("returns the rewardInfo for given week", async function () {
            const value = await vault.viewRewardInfo(1)
            const value2 = await vault.viewRewardInfo(0)
            console.log(value.toString())
            console.log(value2.toString())
            //assert.isTrue(999999999999999999999 >= value[0])
          })
        })
        describe("viewBalance", function () {
          it("view the stablecoin balances of users", async function () {
            const value = await vault.viewBalance(usdcWhale._address, 1)
            assert.equal(value, 5e22)
          })
        })
        describe("viewTotalStakedBalance", function () {
          it("view total amount a user has staked", async function () {
            const value = await vault.viewBalance(usdcWhale._address, 1)
            assert.equal(value, 5e22)
          })
        })
        describe("viewLastClaimed", function () {
          it("returns the last week a user has claimed", async function () {
            const currentWeek = await vault.viewCurrentPeriod()
            const value = await vault.viewLastClaimed(usdcWhale._address)
            assert.equal(value, currentWeek)
          })
        })
        describe("viewClaimedAmount", function () {
          it("returns the amount a user has claimed", async function () {
            const value = await vault.viewClaimedAmount(usdcWhale._address)
            console.log(value.toString())
            //console.log(daiWhaleValue.toString())
            const convertedValue = value.toString().slice(0, -18)
            console.log(convertedValue.toString())
            assert.isTrue(convertedValue > 100)
          })
        })
        describe("viewTotalClaimed", function () {
          it("returns the totalClaimed variable", async function () {
            const value = await vault.viewTotalClaimed()
            const whaleClaim = await vault.viewClaimedAmount(usdcWhale._address)
            console.log("value:", value.toString())
            console.log("claim:", whaleClaim.toString())

            assert.isTrue(BigInt(value) >= BigInt(whaleClaim))
          })
        })
        describe("viewTotalStaked", function () {
          it("returns the totalStaked variable", async function () {
            const value = await vault.viewTotalStaked()
            //console.log(value.toString())
            assert.equal(value, 150000000000000000000000)
          })
        })
        describe("viewUnoDeposit", function () {
          it("returns the amount of STBT that Uno Re has deposited into the vault", async function () {
            const value = await vault.viewUnoDeposit()
            assert.equal(value, 200000000000000000000000)
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
            const number = (value / 2 ** 64) * (unstakeValue / 2 ** 64)
            //console.log(number.toString())
            assert.approximately(number, 1, 0.5)
          })
        })
        describe("viewUnstakeConversionRate", function () {
          it("returns the current unstake STBT / stablecoin conversion", async function () {
            const value = await vault.viewUnstakeConversionRate()
            const stakeValue = await vault.viewStakeConversionRate()
            const number = (value / 2 ** 64) * (stakeValue / 2 ** 64)
            //console.log(number.toString())
            assert.approximately(number, 1, 0.5)
          })
        })
        describe("viewSTBTBalance", function () {
          it("views stbt balance", async function () {
            const stbtBal = await stbt.balanceOf(vault.address)
            console.log(stbtBal.toString())
          })
        })
        // describe("unstake", function () {
        //   it("reverts if `amount` input is zero", async function () {
        //     await expect(
        //       vault.connect(usdcWhale).unstake(0, 1, 99, { gasLimit: 300000 })
        //     ).to.be.revertedWithCustomError(vault, "MatrixUno__ZeroAmountGiven")
        //   })
        //   it("reverts if `token` input is more than two", async function () {
        //     await expect(
        //       vault.connect(usdcWhale).stake(777, 3, 99, { gasLimit: 300000 })
        //     ).to.be.revertedWithCustomError(vault, "MatrixUno__InvalidTokenId")
        //   })
        //   it("transferFrom takes xUNO from user and stores it", async function () {
        //     // To simulate the `claim` function call earning rewards,
        //     // I will transfer 1000 STBT from the STBT usdcWhale to the vault
        //     const initialVaultShares = await vault.balanceOf(vault.address)
        //     const initialVaultAssets = await stbt.balanceOf(vault.address)
        //     const xUnoDeposit = ethers.utils.parseUnits("50000", 18)
        //     const initialVaultAllowance = await vault.allowance(
        //       usdcWhale._address,
        //       vault.address
        //     )
        //     const currentWeek = await vault.viewCurrentPeriod()
        //     const rewardInfo = await vault.viewRewardInfo(currentWeek - 1)
        //     const rewards = rewardInfo.rewards
        //     console.log("initial vault shares:", initialVaultShares.toString())
        //     console.log("initial vault assets:", initialVaultAssets.toString())
        //     console.log(
        //       "initial vault allowance:",
        //       initialVaultAllowance.toString()
        //     )
        //     console.log("rewards:", rewards.toString())
        //     const usdcWhaleBalance = await vault.viewBalance(usdcWhale._address, 1)
        //     const usdcWhaleShares = await vault.balanceOf(usdcWhale._address)
        //     console.log("whaleShares:", usdcWhaleShares.toString())
        //     const totalClaimed = await vault.viewTotalClaimed()
        //     console.log("totalClaimed:", totalClaimed.toString())
        //     console.log("approve:", initialVaultAllowance < xUnoDeposit)
        //     // if (initialVaultAllowance < xUnoDeposit) {
        //     const approveAmount = xUnoDeposit.sub(initialVaultAllowance)
        //     console.log("approveAmount:", approveAmount.toString())
        //     await vault.connect(usdcWhale).approve(vault.address, approveAmount)
        //     console.log("approved!")
        //     //}
        //     const vaultAllowance = await vault.allowance(
        //       usdcWhale._address,
        //       vault.address
        //     )
        //     console.log("vaultAllowance:", vaultAllowance.toString())
        //     console.log("whale vault balance:", usdcWhaleBalance.toString())
        //     console.log(
        //       "currentWeek:",
        //       (await vault.viewCurrentPeriod()).toString()
        //     )
        //     //if (usdcWhaleBalance > 100000000 && totalClaimed == 0) {
        //     const unstakeTx = await vault
        //       .connect(usdcWhale)
        //       .unstake(usdcWhaleShares, 1, 99, { gasLimit: 3000000 })
        //     await unstakeTx.wait(1)
        //     console.log("unstaked!")
        //     //}
        //     // mock rewards sent, now time to test claiming to see if rewards are calculated correctly
        //     const finalVaultShares = await vault.balanceOf(vault.address)
        //     const finalVaultAssets = await stbt.balanceOf(vault.address)
        //     const finalWhaleVaultBalance = await vault.viewBalance(
        //       usdcWhale._address,
        //       1
        //     )
        //     const finalTotalClaimed = await vault.viewTotalClaimed()
        //     console.log("final vault shares:  ", finalVaultShares.toString())
        //     console.log("final vault assets:", finalVaultAssets.toString())
        //     console.log(
        //       "final usdcWhale vbalance:",
        //       finalWhaleVaultBalance.toString()
        //     )
        //     console.log("total assets claimed:", finalTotalClaimed.toString())
        //   })
        //   // it("user stablecoin balance is updated", async function () {
        //   //   // console.log("initial usdc bal:", initialUsdcBal.toString())
        //   //   // const updatedUsdcBal = await usdc.balanceOf(usdcWhale._address)
        //   //   // console.log("updated usdc bal:", updatedUsdcBal.toString())
        //   // })
        //   // it("vault exchanges stbt for stablecoin", async function () {})
        //   // it("vault transfers stablecoin to user", async function () {})
        //   // it("emits the `stablesClaimed` event", async function () {})
        // })
        describe("unstake", function () {
          it("reverts if `amount` input is zero", async function () {
            await expect(
              vault.connect(usdcWhale).unstake(0, 1, 99, { gasLimit: 300000 })
            ).to.be.revertedWithCustomError(vault, "MatrixUno__ZeroAmountGiven")
          })
          it("reverts if `token` input is more than two", async function () {
            await expect(
              vault.connect(usdcWhale).stake(777, 3, 99, { gasLimit: 300000 })
            ).to.be.revertedWithCustomError(vault, "MatrixUno__InvalidTokenId")
          })
          it("transferFrom takes xUNO from uscdWhale and stores it", async function () {
            // To simulate the `claim` function call earning rewards,
            // I will transfer 1000 STBT from the STBT usdcWhale to the vault
            const initialVaultShares = await vault.balanceOf(vault.address)
            const initialVaultAssets = await stbt.balanceOf(vault.address)
            const xUnoDeposit = ethers.utils.parseUnits("50000", 18)
            const initialVaultAllowance = await vault.allowance(
              usdcWhale._address,
              vault.address
            )
            const currentWeek = await vault.viewCurrentPeriod()
            const rewardInfo = await vault.viewRewardInfo(currentWeek - 1)
            const rewards = rewardInfo.rewards
            console.log("initial vault shares:", initialVaultShares.toString())
            console.log("initial vault assets:", initialVaultAssets.toString())
            console.log(
              "initial vault allowance:",
              initialVaultAllowance.toString()
            )
            console.log("rewards:", rewards.toString())
            const usdcWhaleBalance = await vault.viewBalance(
              usdcWhale._address,
              1
            )
            const usdcWhaleShares = await vault.balanceOf(usdcWhale._address)
            console.log("whaleShares:", usdcWhaleShares.toString())
            const totalClaimed = await vault.viewTotalClaimed()
            console.log("totalClaimed:", totalClaimed.toString())
            console.log("approve:", initialVaultAllowance < xUnoDeposit)
            // if (initialVaultAllowance < xUnoDeposit) {
            const approveAmount = xUnoDeposit.sub(initialVaultAllowance)
            console.log("approveAmount:", approveAmount.toString())
            await vault.connect(usdcWhale).approve(vault.address, approveAmount)
            console.log("approved!")
            //}
            const vaultAllowance = await vault.allowance(
              usdcWhale._address,
              vault.address
            )
            console.log("vaultAllowance:", vaultAllowance.toString())
            console.log("whale vault balance:", usdcWhaleBalance.toString())
            console.log(
              "currentWeek:",
              (await vault.viewCurrentPeriod()).toString()
            )
            //if (usdcWhaleBalance > 100000000 && totalClaimed == 0) {
            const unstakeTx = await vault
              .connect(usdcWhale)
              .unstake(usdcWhaleShares, 1, 99, { gasLimit: 3000000 })
            await unstakeTx.wait(1)
            console.log("unstaked!")
            //}
            // mock rewards sent, now time to test claiming to see if rewards are calculated correctly
            const finalVaultShares = await vault.balanceOf(vault.address)
            const finalVaultAssets = await stbt.balanceOf(vault.address)
            const finalWhaleVaultBalance = await vault.viewBalance(
              usdcWhale._address,
              1
            )
            const finalTotalClaimed = await vault.viewTotalClaimed()
            console.log("final vault shares:  ", finalVaultShares.toString())
            console.log("final vault assets:", finalVaultAssets.toString())
            console.log(
              "final usdcWhale vbalance:",
              finalWhaleVaultBalance.toString()
            )
            console.log("total assets claimed:", finalTotalClaimed.toString())
          })
          it("transferFrom takes xUNO from daiWhale and stores it", async function () {
            // To simulate the `claim` function call earning rewards,
            // I will transfer 1000 STBT from the STBT daiWhale to the vault
            const initialVaultShares = await vault.balanceOf(vault.address)
            const initialVaultAssets = await stbt.balanceOf(vault.address)
            const xUnoDeposit = ethers.utils.parseUnits("50000", 18)
            const initialVaultAllowance = await vault.allowance(
              daiWhale._address,
              vault.address
            )
            const currentWeek = await vault.viewCurrentPeriod()
            console.log("unstake checkpoint 1")
            const rewardInfo = await vault.viewRewardInfo(currentWeek - 1)
            const rewards = rewardInfo.rewards
            console.log("initial vault shares:", initialVaultShares.toString())
            console.log("initial vault assets:", initialVaultAssets.toString())
            console.log(
              "initial vault allowance:",
              initialVaultAllowance.toString()
            )
            console.log("rewards:", rewards.toString())
            const daiWhaleBalance = await vault.viewBalance(
              daiWhale._address,
              1
            )
            const daiWhaleShares = await vault.balanceOf(daiWhale._address)
            console.log("whaleShares:", daiWhaleShares.toString())
            const totalClaimed = await vault.viewTotalClaimed()
            console.log("totalClaimed:", totalClaimed.toString())
            console.log("approve:", initialVaultAllowance < xUnoDeposit)
            // if (initialVaultAllowance < xUnoDeposit) {
            const approveAmount = xUnoDeposit.sub(initialVaultAllowance)
            console.log("approveAmount:", approveAmount.toString())
            await vault.connect(daiWhale).approve(vault.address, approveAmount)
            console.log("approved!")
            //}
            const vaultAllowance = await vault.allowance(
              daiWhale._address,
              vault.address
            )
            console.log("vaultAllowance:", vaultAllowance.toString())
            console.log("whale vault balance:", daiWhaleBalance.toString())
            console.log(
              "currentWeek:",
              (await vault.viewCurrentPeriod()).toString()
            )
            //if (daiWhaleBalance > 100000000 && totalClaimed == 0) {
            const unstakeTx = await vault
              .connect(daiWhale)
              .unstake(daiWhaleShares, 0, 99, { gasLimit: 3000000 })
            await unstakeTx.wait(1)
            console.log("unstaked!")
            //}
            // mock rewards sent, now time to test claiming to see if rewards are calculated correctly
            const finalVaultShares = await vault.balanceOf(vault.address)
            const finalVaultAssets = await stbt.balanceOf(vault.address)
            const finalWhaleVaultBalance = await vault.viewBalance(
              daiWhale._address,
              1
            )
            const finalTotalClaimed = await vault.viewTotalClaimed()
            console.log("final vault shares:  ", finalVaultShares.toString())
            console.log("final vault assets:", finalVaultAssets.toString())
            console.log(
              "final daiWhale vbalance:",
              finalWhaleVaultBalance.toString()
            )
            console.log("total assets claimed:", finalTotalClaimed.toString())
          })
          it("transferFrom takes xUNO from usdtWhale and stores it", async function () {
            // To simulate the `claim` function call earning rewards,
            // I will transfer 1000 STBT from the STBT usdtWhale to the vault
            const initialVaultShares = await vault.balanceOf(vault.address)
            const initialVaultAssets = await stbt.balanceOf(vault.address)
            const xUnoDeposit = ethers.utils.parseUnits("50000", 18)
            const initialVaultAllowance = await vault.allowance(
              usdtWhale._address,
              vault.address
            )
            const currentWeek = await vault.viewCurrentPeriod()
            console.log("unstake checkpoint 1")
            const rewardInfo = await vault.viewRewardInfo(currentWeek - 1)
            const rewards = rewardInfo.rewards
            console.log("initial vault shares:", initialVaultShares.toString())
            console.log("initial vault assets:", initialVaultAssets.toString())
            console.log(
              "initial vault allowance:",
              initialVaultAllowance.toString()
            )
            console.log("rewards:", rewards.toString())
            const usdtWhaleBalance = await vault.viewBalance(
              usdtWhale._address,
              1
            )
            const usdtWhaleShares = await vault.balanceOf(usdtWhale._address)
            console.log("whaleShares:", usdtWhaleShares.toString())
            const totalClaimed = await vault.viewTotalClaimed()
            console.log("totalClaimed:", totalClaimed.toString())
            console.log("approve:", initialVaultAllowance < xUnoDeposit)
            // if (initialVaultAllowance < xUnoDeposit) {
            const approveAmount = xUnoDeposit.sub(initialVaultAllowance)
            console.log("approveAmount:", approveAmount.toString())
            await vault.connect(usdtWhale).approve(vault.address, approveAmount)
            console.log("approved!")
            //}
            const vaultAllowance = await vault.allowance(
              usdtWhale._address,
              vault.address
            )
            console.log("vaultAllowance:", vaultAllowance.toString())
            console.log("whale vault balance:", usdtWhaleBalance.toString())
            console.log(
              "currentWeek:",
              (await vault.viewCurrentPeriod()).toString()
            )
            //if (usdtWhaleBalance > 100000000 && totalClaimed == 0) {
            const unstakeTx = await vault
              .connect(usdtWhale)
              .unstake(usdtWhaleShares, 2, 99, { gasLimit: 3000000 })
            await unstakeTx.wait(1)
            console.log("unstaked!")
            //}
            // mock rewards sent, now time to test claiming to see if rewards are calculated correctly
            const finalVaultShares = await vault.balanceOf(vault.address)
            const finalVaultAssets = await stbt.balanceOf(vault.address)
            const finalWhaleVaultBalance = await vault.viewBalance(
              usdtWhale._address,
              1
            )
            const finalTotalClaimed = await vault.viewTotalClaimed()
            console.log("final vault shares:  ", finalVaultShares.toString())
            console.log("final vault assets:", finalVaultAssets.toString())
            console.log(
              "final usdtWhale vbalance:",
              finalWhaleVaultBalance.toString()
            )
            console.log("total assets claimed:", finalTotalClaimed.toString())
          })
          // it("user stablecoin balance is updated", async function () {
          //   // console.log("initial usdc bal:", initialUsdcBal.toString())
          //   // const updatedUsdcBal = await usdc.balanceOf(usdcWhale._address)
          //   // console.log("updated usdc bal:", updatedUsdcBal.toString())
          // })
          // it("vault exchanges stbt for stablecoin", async function () {})
          // it("vault transfers stablecoin to user", async function () {})
          // it("emits the `stablesClaimed` event", async function () {})
        })
      })
})
