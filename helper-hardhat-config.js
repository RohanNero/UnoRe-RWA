const networkConfig = {
  1337: {
    name: "localhost",
    keyHash:
      "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15",
    subId: "777",
    blockConfirmations: "1",
    callbackGaslimit: "500000",
    vrfCoordinator: "0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D",
  },
  5: {
    name: "goerli",
    keyHash:
      "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15",
    subId: "777",
    blockConfirmations: "5",
    callbackGaslimit: "500000",
    vrfCoordinator: "0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D",
  },
  80001: {
    name: "mumbai",
    keyHash:
      "0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f",
    subId: "3222",
    blockConfirmations: "5",
    callbackGaslimit: "500000",
    vrfCoordinator: "0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed",
  },
  43113: {
    name: "fuji",
    keyHash:
      "0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61",
    subId: "550",
    blockConfirmations: "5",
    callbackGaslimit: "500000",
    vrfCoordinator: "0x2eD832Ba664535e5886b75D64C46EB9a228C2610",
  },
}

const developmentChains = ["hardhat", "localhost"]

module.exports = {
  developmentChains,
  networkConfig,
}
