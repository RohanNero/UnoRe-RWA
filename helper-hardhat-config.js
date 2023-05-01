const networkConfig = {
  1337: {
    name: "localhost",
    blockConfirmations: "1",
  },
  5: {
    name: "goerli",
    blockConfirmations: "5",
  },
  80001: {
    name: "mumbai",
    blockConfirmations: "5",
  },
  43113: {
    name: "fuji",
    blockConfirmations: "5",
  },
}

const developmentChains = ["hardhat", "localhost"]

module.exports = {
  developmentChains,
  networkConfig,
}
