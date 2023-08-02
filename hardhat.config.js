require("@nomiclabs/hardhat-etherscan")
require("@nomicfoundation/hardhat-network-helpers")
require("@nomicfoundation/hardhat-chai-matchers")
require("@nomiclabs/hardhat-ethers")
require("@nomiclabs/hardhat-vyper")
require("hardhat-deploy")
require("hardhat-contract-sizer")
require("hardhat-gas-reporter")
require("prettier")
require("prettier-plugin-solidity")
require("solidity-coverage")
require("dotenv").config()

const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL
const MUMBAI_RPC_URL = process.env.MUMBAI_RPC_URL
const FUJI_RPC_URL = process.env.FUJI_RPC_URL
const PRIVATE_KEY = process.env.PRIVATE_KEY
const USER_PRIVATE_KEY = process.env.USER_PRIVATE_KEY
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY
const SNOWTRACE_API_KEY = process.env.SNOWTRACE_API_KEY
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY

/**@dev this task deposits `amount` of STBT into the matrixUno vault */
task("matrixDeposit", "deposits `amount` of STBT into the matrixUno vault")
  //.addParam("address", "TokenWizardAuto contract address you wish to view")
  .addParam("amount", "amount of STBT to be deposited")
  .addParam("receiver", "address to receive the STBT")
  .setAction(async ({ amount, receiver }) => {
    const { stbtAbi } = require("./helper-hardhat-config.js")
    const vault = await ethers.getContract("MatrixUno")
    const stbt = await ethers.getContractAt(
      stbtAbi,
      "0x0f539454d2effd45e9bfed7c57b2d48bfd04cb32"
    )

    const cAmount = (amount * 1e18).toString()
    const approveArgs = [vault.address, cAmount]
    await stbt.approve({ args: vault.address, cAmount })
    console.log(vault.address)
    await vault.deposit(cAmount, receiver)
    //console.log(value.toString())
  })

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  vyper: {
    compilers: [
      { version: "0.2.15" },
      { version: "0.3.0" },
      { version: "0.3.7" },
    ],
  },
  solidity: {
    compilers: [
      {
        version: "0.8.7",
        settings: {
          optimizer: {
            enabled: true,
            runs: 77,
          },
        },
      },
      { version: "0.8.12" },
      { version: "0.7.7" },
    ],
  },
  namedAccounts: {
    deployer: 0,
    user: 1,
  },
  gasReporter: {
    enabled: false,
  },
  networks: {
    hardhat: {
      blockConfirmations: 1,
      // blockGasLimit: 10000000000077000000,
      // gas: 8000000000770000,
      chainId: 1337,
      forking: {
        url: process.env.FORKING_URL,
        blockNumber: 17372500,
      },
    },
    goerli: {
      chainId: 5,
      blockConfirmations: 5,
      url: GOERLI_RPC_URL,
      accounts: [PRIVATE_KEY, USER_PRIVATE_KEY],
    },
    mumbai: {
      chainId: 80001,
      blockConfirmations: 5,
      url: MUMBAI_RPC_URL,
      accounts: [PRIVATE_KEY],
    },
    fuji: {
      chainId: 43113,
      blockConfirmations: 5,
      url: FUJI_RPC_URL,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      goerli: ETHERSCAN_API_KEY,
      polygonMumbai: POLYGONSCAN_API_KEY,
      avalancheFujiTestnet: SNOWTRACE_API_KEY,
    },
  },
  mocha: {
    timeout: 100000000,
  },
}
