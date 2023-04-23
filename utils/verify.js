const { run } = require("hardhat")

const verify = async function (address, args) {
  try {
    await run("verify:verify", {
      address: address,
      constructorArguments: args,
    })
  } catch (error) {
    if (error.message.toLowerCase().includes("already verified")) {
      console.log("Already verified!")
    } else {
      console.log(error)
    }
  }
}

module.exports = { verify }
