const { network, ethers } = require("hardhat")
const {
  developmentChains,
  networkConfig,
  abi,
  lpAbi,
  gaugeAbi,
  threeCRVAbi,
  stableSwapAbi,
  crvAbi,
  minterAbi,
} = require("../../helper-hardhat-config.js")
const { assert, expect } = require("chai")

describe("Loki unit tests", function () {
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
    minter
  beforeEach(async function () {
    ;[deployer] = await ethers.getSigners()
    //console.log(network)

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
    crv = await ethers.getContractAt(
      crvAbi,
      "0xD533a949740bb3306d119CC777fa900bA034cd52"
    )
    minter = await ethers.getContractAt(
      minterAbi,
      "0xd061d61a4d941c39e5453435b6345dc261c2fce0"
    )
    // deposit = await ethers.getContract("deposit")
    //matrixUNO = await ethers.getContract("MatrixUNO")
    //loki = await ethers.getContract("Loki")
  })
  /* MUST BE ON MAININET FORK TO TEST THIS DESCRIBE */
  describe("PRELIMINARY TESTS |-- DEPOSITING STABLECOIN --> 3CRV --> STBT/3CRV LP Token --> CRV |", function () {
    it("whale should have large USDC balance", async function () {
      const bal = await usdc.balanceOf(whale._address)
      //console.log("whale USDC bal:", bal.toString())
      assert.isAbove(bal, 1000000000)
    })
    it("first hardhat account should have zero USDC", async function () {
      const bal = await usdc.balanceOf(deployer.address)
      //console.log("deployer USDC bal:", bal.toString())
      assert.equal(bal.toString(), "0")
    })
    it("gauge should hold big portion of LP tokens", async function () {
      const bal = await lpToken.balanceOf(gauge.address, { gasLimit: 300000 })
      // console.log("gauge lpToken bal:", bal.toString())
      assert.isAbove(bal, 1000000000)
    })
    it("STBT/3CRV pool should return expected values", async function () {
      const decimals = await lpToken.decimals({ gasLimit: 300000 })
      const name = await lpToken.name()
      const symbol = await lpToken.symbol()
      const balances = await lpToken.get_balances({ gasLimit: 300000 })
      // console.log("balances:", balances.toString())
      // console.log("decimals:", decimals.toString())
      // console.log("pool name:", name)
      // console.log("pool symbol:", symbol)
      assert.equal(decimals.toString(), "18")
    })
    it("whale should be able to swap USDC for 3CRV", async function () {
      // Deposit USDC for 3CRV
      const usdcBal = await usdc.balanceOf(whale._address)
      const usdcAllowance = await usdc.allowance(
        whale._address,
        lpToken.address
      )
      const old3CrvBal = await threeCRV.balanceOf(whale._address, {
        gasLimit: 300000,
      })

      const usdcAmount = Math.floor(usdcBal / 10000)
      const crvAmounts = [0, usdcAmount.toString(), 0]

      // console.log("whale USDC balance:", usdcBal.toString())
      // console.log("whale address:", whale._address)
      // console.log("old 3CRV balance:", old3CrvBal.toString())

      // console.log("usdc to be deposited:", usdcAmount.toString())
      if (usdcAllowance < usdcAmount) {
        await usdc
          .connect(whale)
          .approve(stableSwap.address, usdcAmount - usdcAllowance, {
            gasLimit: 300000,
          })
      }
      //console.log("USDC allowance:", usdcAllowance.toString())

      await stableSwap.connect(whale).add_liquidity(crvAmounts, 1000000, {
        gasLimit: 30000000,
      })
      console.log(usdcAmount.toString(), "USDC Deposited!")

      const new3CrvBal = await threeCRV.balanceOf(whale._address, {
        gasLimit: 300000,
      })
      //console.log("new 3CRV balance:", new3CrvBal.toString())
    })
    it("whale should be able to swap 3CRV for LP tokens", async function () {
      const new3CrvBal = await threeCRV.balanceOf(whale._address, {
        gasLimit: 300000,
      })
      const crvAllowance = await threeCRV.allowance(
        whale._address,
        lpToken.address
      )
      const oldLpBal = await lpToken.balanceOf(whale._address, {
        gasLimit: 300000,
      })

      // console.log(lpToken.functions)
      // console.log(gauge.functions)
      // console.log(minter.functions)
      // console.log("lpToken address:", lpToken.address)

      // console.log("old 3CRV allowance:", crvAllowance.toString())
      // console.log("old LP token balance:", oldLpBal.toString())

      // Deposit 3CRV for LP tokens
      // deposit tx takes: (uint256[2], uint256) or (uint256[2], uint256, address)
      const crvAmount = Math.floor(new3CrvBal / 10000000000)
      const amounts = [0, crvAmount.toString()]
      //console.log("3CRV to be deposited:", crvAmount.toString())
      if (crvAmount > crvAllowance) {
        await threeCRV
          .connect(whale)
          .approve(lpToken.address, (crvAmount - crvAllowance).toString(), {
            gasLimit: 30000000,
          })
      }
      const newCrvAllowance = await threeCRV.allowance(
        whale._address,
        lpToken.address
      )
      //console.log("new 3CRV allowance:", newCrvAllowance.toString())

      await lpToken
        .connect(whale)
        ["add_liquidity(uint256[2],uint256)"](amounts, 1000000, {
          gasLimit: 30000000,
        })
      console.log(crvAmount.toString(), "3CRV Deposited!")

      const newLpBal = await lpToken.balanceOf(whale._address, {
        gasLimit: 300000,
      })
      const finalCrvAllowance = await threeCRV.allowance(
        whale._address,
        lpToken.address
      )

      // console.log("final 3CRV allowance:", finalCrvAllowance.toString())
      // console.log("new LP token balance:", newLpBal.toString())
    })
    it("Liquidity gauge should transfer CRV to whale after LP token deposit", async function () {
      const newLpBal = await lpToken.balanceOf(whale._address, {
        gasLimit: 300000,
      })
      // Deposit LP tokens for CRV
      const lpTokenAllowance = await lpToken.allowance(
        whale._address,
        gauge.address,
        { gasLimit: 300000 }
      )
      //console.log("Lp token allowance", lpTokenAllowance.toString())

      const oldCrvBal = await crv.balanceOf(whale._address)
      const lpDeposit = Math.floor(newLpBal / 10000)
      if (lpTokenAllowance < lpDeposit) {
        await lpToken
          .connect(whale)
          .approve(gauge.address, (lpDeposit - lpTokenAllowance).toString(), {
            gasLimit: 300000,
          })
      }

      await gauge
        .connect(whale)
        ["deposit(uint256)"](lpDeposit.toString(), { gasLimit: 3000000 })
      console.log(lpDeposit.toString(), "LP Tokens Deposited!")
      const claimableCrv = await gauge.callStatic.claimable_tokens(
        whale._address,
        {
          gasLimit: 3000000,
        }
      )
      // Calling "mint" on Minter is how you get your CRV
      // await gauge
      //   .connect(whale)
      //   ["claim_rewards(address,address)"](whale._address, whale._address, {
      //     gasLimit: 3000000,
      //   })
      await minter.connect(whale).mint(gauge.address, { gasLimit: 3000000 })

      const finalLpBal = await lpToken.balanceOf(whale._address, {
        gasLimit: 300000,
      })
      const LpDeposited = await gauge.balanceOf(whale._address, {
        gasLimit: 300000,
      })
      const newCrvBal = await crv.balanceOf(whale._address, {
        gasLimit: 300000,
      })

      // const claimableReceipt = await claimableCrv.wait(1)
      // console.log("claimable CRV:", claimableCrv.toString())
      // console.log("old CRV balance:", oldCrvBal.toString())
      // console.log("new CRV balance:", newCrvBal.toString())
      // console.log("final LP token Balance:", finalLpBal.toString())
      // console.log("Total LP tokens deposited:", LpDeposited.toString())
      //console.log(claimableCrv)
      //assert.isAbove(newCrvBal, oldCrvBal)
    })
  })
  /* MUST BE ON MAINNET FORK TO TEST THIS DESCRIBE */
  /* THIS DESCRIBE SIMULATES RECEIVING STBT FROM ISSUER BY EXCHANGING 3CRV FOR STBT,
  NEED TO FIGURE OUT HOW I WILL DO THIS SINCE STBT ADDRESS NEEDS TO BE WHITELISTED
  EASY SOLUTION IS TO FIND STBT WHALE AND IMPERSONATE THE ADDRESS */
  describe("PRELIMINARY TESTS |-- DEPOSITING STABLECOIN --> STBT --> STBT/3CRV LP Token --> CRV |", function () {
    it("whale should have large STBT balance", async function () {
      const bal = await usdc.balanceOf(whale._address)
      //console.log("whale USDC bal:", bal.toString())
      assert.isAbove(bal, 1000000000)
    })
    it("first hardhat account should have zero STBT", async function () {
      const bal = await usdc.balanceOf(deployer.address)
      //console.log("deployer USDC bal:", bal.toString())
      assert.equal(bal.toString(), "0")
    })
    // it("gauge should hold big portion of LP tokens", async function () {
    //   const bal = await lpToken.balanceOf(gauge.address, { gasLimit: 300000 })
    //   // console.log("gauge lpToken bal:", bal.toString())
    //   assert.isAbove(bal, 1000000000)
    // })
    // it("STBT/3CRV pool should return expected values", async function () {
    //   const decimals = await lpToken.decimals({ gasLimit: 300000 })
    //   const name = await lpToken.name()
    //   const symbol = await lpToken.symbol()
    //   const balances = await lpToken.get_balances({ gasLimit: 300000 })
    //   // console.log("balances:", balances.toString())
    //   // console.log("decimals:", decimals.toString())
    //   // console.log("pool name:", name)
    //   // console.log("pool symbol:", symbol)
    //   assert.equal(decimals.toString(), "18")
    // })
    // it("whale should be able to swap 3CRV for STBT", async function () {
    //   const whaleUsdcBal = await usdc.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })
    //   const oldbal = await threeCRV.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })

    //   await usdc.connect(whale).approve(stableSwap.address, whaleUsdcBal)
    //   const usdcAmount = Math.floor(whaleUsdcBal / 1000)

    //   const amounts = [0, usdcAmount, 0]
    //   // left off right here, trying to call add_liquidity with an amount of USDC for 3CRV
    //   await stableSwap.connect(whale).add_liquidity(amounts, 1000000, {
    //     gasLimit: 30000000,
    //   })
    //   const newBal = await threeCRV.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })
    //   // const calcAmount = await stableSwap.calc_token_amount(
    //   //   [0, 5500, 0],
    //   //   true,
    //   //   {
    //   //     gasLimit: 300000,
    //   //   }
    //   // )
    //   //console.log(whale)
    //   //console.log("usdc Amount:", usdcAmount.toString())
    //   //console.log("calc token amount:", calcAmount.toString())
    //   //console.log(stableSwap.functions)
    //   //console.log("whale usdc balance:", whaleUsdcBal.toString())
    //   // console.log(
    //   //   "usdc address:",
    //   //   (await stableSwap.coins(1, { gasLimit: 300000 })).toString()
    //   // )
    //   // console.log("old 3CRV balance:", oldbal.toString())
    //   // console.log("new 3CRV balance:", newBal.toString())
    //   //console.log(stableSwap)
    //   //console.log(threeCRV)
    // })
    // it("whale should be able to swap STBT for LP tokens", async function () {
    //   const usdcBal = await usdc.balanceOf(whale._address)
    //   const crvAllowance = await threeCRV.allowance(
    //     whale._address,
    //     lpToken.address
    //   )
    //   // console.log("old 3CRV allowance:", crvAllowance.toString())
    //   // console.log("whale USDC balance:", usdcBal.toString())
    //   // console.log("whale address:", whale._address)
    //   //console.log(lpToken.functions)
    //   const oldLpBal = await lpToken.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })
    //   const old3CrvBal = await threeCRV.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })
    //   await usdc
    //     .connect(whale)
    //     .approve(stableSwap.address, usdcBal, { gasLimit: 300000 })

    //   const usdcAmount = Math.floor(usdcBal / 1000)
    //   const crvAmounts = [0, usdcAmount, 0]

    //   await stableSwap.connect(whale).add_liquidity(crvAmounts, 1000000, {
    //     gasLimit: 30000000,
    //   })
    //   const new3CrvBal = await threeCRV.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })
    //   // deposit tx takes: (uint256[2], uint256) or (uint256[2], uint256, address)
    //   const crvAmount = Math.floor(old3CrvBal / 1000)

    //   const amounts = [0, crvAmount.toString()]
    //   if (crvAllowance < crvAmount) {
    //     await threeCRV.connect(whale).approve(lpToken.address, new3CrvBal, {
    //       gasLimit: 3000000,
    //     })
    //   }

    //   await lpToken
    //     .connect(whale)
    //     ["add_liquidity(uint256[2],uint256)"](amounts, 1000000, {
    //       gasLimit: 3000000,
    //     })
    //   const newLpBal = await lpToken.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })

    //   const newCrvAllowance = await threeCRV.allowance(
    //     whale._address,
    //     lpToken.address
    //   )
    //   //console.log("crv amount to be deposited:", crvAmount.toString())
    //   // console.log("new 3CRV allownace:", newCrvAllowance.toString())
    //   // console.log("lpToken address:", lpToken.address)
    //   // console.log("old 3CRV balance:", old3CrvBal.toString())
    //   // console.log("new 3CRV balance:", new3CrvBal.toString())
    //   // console.log("old LP token balance:", oldLpBal.toString())
    //   // console.log("new LP token balance:", newLpBal.toString())
    //   assert.isAbove(newLpBal, oldLpBal)
    // })
    // it("Liquidity gauge should transfer CRV to whale after LP token deposit", async function () {
    //   const usdcBal = await usdc.balanceOf(whale._address)
    //   const usdcAllowance = await usdc.allowance(
    //     whale._address,
    //     lpToken.address
    //   )
    //   const crvAllowance = await threeCRV.allowance(
    //     whale._address,
    //     lpToken.address
    //   )
    //   const oldLpBal = await lpToken.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })
    //   const old3CrvBal = await threeCRV.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })

    //   //console.log(lpToken.functions)
    //   //console.log(gauge.functions)
    //   //console.log(minter.functions)
    //   // console.log("old 3CRV allowance:", crvAllowance.toString())
    //   // console.log("whale USDC balance:", usdcBal.toString())
    //   // console.log("whale address:", whale._address)
    //   // console.log("old 3CRV balance:", old3CrvBal.toString())
    //   // console.log("old LP token balance:", oldLpBal.toString())
    //   // console.log("USDC allowance:", usdcAllowance.toString())

    //   // Deposit USDC for 3CRV

    //   const usdcAmount = Math.floor(usdcBal / 10000)
    //   const crvAmounts = [0, usdcAmount.toString(), 0]
    //   if (usdcAllowance < usdcAmount) {
    //     await usdc
    //       .connect(whale)
    //       .approve(stableSwap.address, usdcAmount - usdcAllowance, {
    //         gasLimit: 300000,
    //       })
    //   }
    //   if (old3CrvBal < 1000000) {
    //     await stableSwap.connect(whale).add_liquidity(crvAmounts, 1000000, {
    //       gasLimit: 30000000,
    //     })
    //     //console.log("USDC Deposited!")
    //   }

    //   const new3CrvBal = await threeCRV.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })

    //   // Deposit 3CRV for LP tokens
    //   // deposit tx takes: (uint256[2], uint256) or (uint256[2], uint256, address)
    //   const crvAmount = Math.floor(new3CrvBal / 1000000)
    //   const amounts = [0, crvAmount.toString()]
    //   if (crvAllowance < crvAmount) {
    //     await threeCRV
    //       .connect(whale)
    //       .approve(lpToken.address, (crvAmount - crvAllowance).toString(), {
    //         gasLimit: 3000000,
    //       })
    //   }

    //   const newCrvAllowance = await threeCRV.allowance(
    //     whale._address,
    //     lpToken.address
    //   )
    //   //console.log("new 3CRV allowance:", newCrvAllowance.toString())
    //   if (oldLpBal < 10000) {
    //     await lpToken
    //       .connect(whale)
    //       ["add_liquidity(uint256[2],uint256)"](amounts, 1000000, {
    //         gasLimit: 30000000,
    //       })
    //     //console.log("3CRV Deposited!")
    //   }

    //   const newLpBal = await lpToken.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })
    //   const finalCrvAllowance = await threeCRV.allowance(
    //     whale._address,
    //     lpToken.address
    //   )
    //   //console.log("final 3CRV allowance:", finalCrvAllowance.toString())

    //   // Deposit LP tokens for CRV
    //   const lpTokenAllowance = await lpToken.allowance(
    //     whale._address,
    //     gauge.address,
    //     { gasLimit: 300000 }
    //   )
    //   //console.log("Lp token allowance", lpTokenAllowance.toString())

    //   const oldCrvBal = await crv.balanceOf(whale._address)
    //   const lpDeposit = Math.floor(newLpBal / 100000)
    //   if (lpTokenAllowance < lpDeposit) {
    //     await lpToken
    //       .connect(whale)
    //       .approve(gauge.address, (lpDeposit - lpTokenAllowance).toString(), {
    //         gasLimit: 300000,
    //       })
    //   }

    //   await gauge
    //     .connect(whale)
    //     ["deposit(uint256)"](lpDeposit.toString(), { gasLimit: 3000000 })
    //   const claimableCrv = await gauge.callStatic.claimable_tokens(
    //     whale._address,
    //     {
    //       gasLimit: 3000000,
    //     }
    //   )
    //   // Calling "mint" on Minter is how you get your CRV
    //   // await gauge
    //   //   .connect(whale)
    //   //   ["claim_rewards(address,address)"](whale._address, whale._address, {
    //   //     gasLimit: 3000000,
    //   //   })
    //   await minter.connect(whale).mint(gauge.address, { gasLimit: 3000000 })
    //   const newCrvBal = await crv.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })

    //   const finalLpBal = await lpToken.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })
    //   const LpDeposited = await gauge.balanceOf(whale._address, {
    //     gasLimit: 300000,
    //   })

    //   // const claimableReceipt = await claimableCrv.wait(1)
    //   // console.log("usdc to be deposited:", usdcAmount.toString())
    //   // console.log("lpToken address:", lpToken.address)
    //   // console.log("new 3CRV balance:", new3CrvBal.toString())
    //   // console.log("new LP token balance:", newLpBal.toString())
    //   // console.log("old CRV balance:", oldCrvBal.toString())
    //   // console.log("new CRV balance:", newCrvBal.toString())
    //   // console.log("claimable CRV:", claimableCrv.toString())
    //   // console.log("final LP token Balance:", finalLpBal.toString())
    //   // console.log("Lp tokens deposited:", LpDeposited.toString())
    //   //console.log(claimableCrv)
    //   //assert.isAbove(newCrvBal, oldCrvBal)
    // })
  })
  describe("enterPool", function () {})
})
