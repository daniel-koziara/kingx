require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config()

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
      forking: {
        url: process.env.RPC_URL,
      }
    },
    localnode: {
      url: "http://127.0.0.1:8545",
    }
  }
};
