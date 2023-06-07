require("@nomiclabs/hardhat-etherscan")
require("hardhat-deploy")
require("@nomicfoundation/hardhat-chai-matchers")
require("@nomiclabs/hardhat-ethers")
require("@nomiclabs/hardhat-vyper")
require("dotenv").config()
require("hardhat-contract-sizer")
require("hardhat-gas-reporter")
require("prettier")
require("prettier-plugin-solidity")
require("solidity-coverage")

const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL
const MUMBAI_RPC_URL = process.env.MUMBAI_RPC_URL
const FUJI_RPC_URL = process.env.FUJI_RPC_URL
const PRIVATE_KEY = process.env.PRIVATE_KEY
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY
const SNOWTRACE_API_KEY = process.env.SNOWTRACE_API_KEY
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY

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
      { version: "0.8.7" },
      { version: "0.8.12" },
      { version: "0.7.7" },
    ],
  },
  namedAccounts: {
    deployer: 0,
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
      accounts: [PRIVATE_KEY],
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
