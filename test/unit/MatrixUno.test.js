const { network, ethers } = require("hardhat")
const hre = require("hardhat")
const { setCode } = require("@nomicfoundation/hardhat-network-helpers")
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

describe("MatrixUno Unit Tests", function () {
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
    const provider = new ethers.providers.JsonRpcProvider(
      "http://localhost:8545"
    )
    // await provider.send("hardhat_impersonateAccount", [
    //   "0x171cda359aa49E46Dec45F375ad6c256fdFBD420",
    // ])
    whale = provider.getSigner("0x171cda359aa49E46Dec45F375ad6c256fdFBD420")
    // This method kept throwing error messages from time to time so now he is green :p
    //whale = await ethers.getSigner("0x171cda359aa49E46Dec45F375ad6c256fdFBD420")
    //console.log(whale)
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
    //initialUsdcBal = await usdc.balanceOf(whale._address)
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
            // console.log("STBT whale address:", sWhale._address)
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
                gasLimit: 300000,
              })
              //console.log(stbtDeposit.toString(), "STBT approved!")
            }
            if (vaultStbtBalance < stbtDeposit / 2) {
              await vault.connect(sWhale).deposit(stbtDeposit, vault.address, {
                gasLimit: 300000,
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
            assert.isTrue(vaultSharesBalanceSliced >= 99999)
          })
          // Actual MatrixUno `stake()` function calls
          it("reverts if `amount` input is zero", async function () {
            await hre.network.provider.request({
              method: "hardhat_impersonateAccount",
              params: [whale._address],
            })
            await expect(
              vault.connect(whale).stake(0, 1, { gasLimit: 300000 })
            ).to.be.revertedWithCustomError(vault, "MatrixUno__ZeroAmountGiven")
          })
          it("reverts if `token` input is more than two", async function () {
            await expect(
              vault.connect(whale).stake(777, 3, { gasLimit: 300000 })
            ).to.be.revertedWithCustomError(vault, "MatrixUno__InvalidTokenId")
          })
          // The important one
          it("transfers the stablecoins from user to vault", async function () {
            const initialVaultUsdcBalance = await usdc.balanceOf(vault.address)
            const usdcBalance = await usdc.balanceOf(whale._address)
            const usdcAllowance = await usdc.allowance(
              whale._address,
              vault.address
            )
            const usdcDeposit = 50000 * 1e6
            // console.log("whale usdc balance:", usdcBalance.toString())
            // console.log("vault usdc allowance:", usdcAllowance.toString())
            // console.log(
            //   "initial vault usdc balance:",
            //   initialVaultUsdcBalance.toString()
            // )

            if (usdcAllowance < usdcDeposit) {
              await usdc
                .connect(whale)
                .approve(vault.address, usdcDeposit.toString())
            }
            const updatedUsdcAllowance = await usdc.allowance(
              whale._address,
              vault.address
            )
            const totalClaimed = await vault.viewTotalClaimed()
            // console.log("updated usdc allowance:", updatedUsdcAllowance.toString())
            // console.log("total claimed:", totalClaimed.toString())
            // console.log((await vault.balanceOf(vault.address)).toString())
            // console.log("usdcDeposit:",usdcDeposit.toString())
            if (initialVaultUsdcBalance < usdcDeposit) {
              const shares = await vault
                .connect(whale)
                .stake(usdcDeposit, 1, { gasLimit: 300000 })
            }
            //console.log("staked!")

            const finalVaultUsdcBalance = await usdc.balanceOf(vault.address)
            //console.log("final vault usdc balance:", finalVaultUsdcBalance.toString())
          })
          // come back to this test later
        //   it("`transferFromAmount` is less than provided `amount` if vault doesn't have enough xUNO", async function () {})
          it("updates the user's balance for the staked stablecoin", async function () {
            const vaultBalance = await vault.viewStakedBalance(whale._address, 1)
            const totalClaimed = await vault.viewTotalClaimed()
            //console.log("whale usdc balance:", vaultBalance.toString())
            //console.log("total claimed:", totalClaimed.toString())
            // eventually need to make > into = since unstake should be working properly
            assert.isTrue(vaultBalance >= 50000000000 || totalClaimed > 0)
          })
          it("transfers xUNO to the user", async function () {
            const whalexUnoBalance = await vault.balanceOf(whale._address)
            const vaultxUnoBalance = await vault.balanceOf(vault.address)
            const vaultSymbol = await vault.symbol()
            const slicedWhaleBalance = whalexUnoBalance.toString().slice(0, -18)
            const totalClaimed = await vault.viewTotalClaimed()
            // console.log("whale xUNO balance:", whalexUnoBalance.toString())
            // console.log("vault xUNO balance:", vaultxUnoBalance.toString())
            // console.log("vault shares symbol:", vaultSymbol.toString())
            // console.log("total claimed:", totalClaimed.toString())
            assert.isTrue(slicedWhaleBalance > 1000 || totalClaimed > 0)
          })
        })
        describe("unstake", function () {
          it("reverts if `amount` input is zero", async function () {
            await expect(
              vault.connect(whale).unstake(0, 1, { gasLimit: 300000 })
            ).to.be.revertedWithCustomError(vault, "MatrixUno__ZeroAmountGiven")
          })
          it("reverts if `token` input is more than two", async function () {
            await expect(
              vault.connect(whale).stake(777, 3, { gasLimit: 300000 })
            ).to.be.revertedWithCustomError(vault, "MatrixUno__InvalidTokenId")
          })
          it("transferFrom takes xUNO from user and stores it", async function () {
            // To simulate the `claim` function call earning rewards,
            // I will transfer 1000 STBT from the STBT whale to the vault

            const initialVaultShares = await vault.balanceOf(vault.address)
            const initialVaultAssets = await stbt.balanceOf(vault.address)
            const thousandStbt = ethers.utils.parseUnits("1000", 18)
            const slicedVaultAssets = initialVaultAssets
              .toString()
              .slice(0, -18)
            const initialVaultAllowance = await vault.allowance(
              whale._address,
              vault.address
            )
            const xUnoDeposit = 50000 * 1e6
            const whaleBalance = await vault.viewStakedBalance(whale._address,1)
            const totalClaimed = await vault.viewTotalClaimed()

            if (slicedVaultAssets < 200000) {
              await stbt.connect(sWhale).transfer(vault.address, thousandStbt)
              //console.log("mock stbt rewards distributed!")
            }
            if (initialVaultAllowance < xUnoDeposit) {
              await vault
                .connect(whale)
                .approve(vault.address, xUnoDeposit - initialVaultAllowance)
            }
            //console.log("whale vault balance:", whaleBalance.toString())
            if (whaleBalance > 100000000 && totalClaimed == 0) {
              const claimTx = await vault
                .connect(whale)
                .unstake(xUnoDeposit, 1, { gasLimit: 3000000 })
              await claimTx.wait(1)
            }

            // mock rewards sent, now time to test claiming to see if rewards are calculated correctly
            const finalVaultShares = await vault.balanceOf(vault.address)
            const finalVaultAssets = await stbt.balanceOf(vault.address)
            const finalWhaleVaultBalance = await vault.viewStakedBalance(whale._address, 1)
            const finalTotalClaimed = await vault.viewTotalClaimed()
            // console.log("initial vault shares:", initialVaultShares.toString())
            // console.log("initial vault assets:", initialVaultAssets.toString())
            // console.log("initial vault allowance:", initialVaultAllowance.toString())
            // console.log("final vault shares:  ", finalVaultShares.toString())
            // console.log("final vault assets:", finalVaultAssets.toString())
            // console.log("final whale vbalance:", finalWhaleVaultBalance.toString())
            // console.log("total assets claimed:", finalTotalClaimed.toString())
          })
          it("user stablecoin balance is updated", async function () {
            // console.log("initial usdc bal:", initialUsdcBal.toString())
            // const updatedUsdcBal = await usdc.balanceOf(whale._address)
            // console.log("updated usdc bal:", updatedUsdcBal.toString())
          })
          it("vault exchanges stbt for stablecoin", async function () {})
          it("vault transfers stablecoin to user", async function () {})
          it("emits the `stablesClaimed` event", async function () {})
        })
      })
})
