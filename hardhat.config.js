require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");


/** @type import('hardhat/config').HardhatUserConfig */ 
require('dotenv').config();

const AURORA_PRIVATE_KEY = process.env.AURORA_PRIVATE_KEY;
const alchemy_APIKEY = process.env.alchemy_APIKEY;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY; // arb
const ETHERSCAN_API_KEY_MAIN = process.env.ETHERSCAN_API_KEY_MAIN
module.exports = {
  solidity: "0.8.19",
  solidity: {
    compilers: [
      {
        version: "0.7.6",
      },
      {
        version: "0.8.0",
      },
      {
        version: "0.8.19",
      },
    ],
  },
  settings: {
    viaIR: true,
    optimizer: {
      enabled: true,
      details: {
        yulDetails: {
          optimizerSteps: "u",
        },
      },
    },
  },
  etherscan: {
    apiKey: {
      arbitrumGoerli: ETHERSCAN_API_KEY,
      goerli: ETHERSCAN_API_KEY_MAIN,
      arbitrumOne:ETHERSCAN_API_KEY,
    }
  },
  networks: {
    arb_goerli: {
      url: 'https://arb-goerli.g.alchemy.com/v2/'+`${alchemy_APIKEY}`,
      accounts: [`0x${AURORA_PRIVATE_KEY}`],
      chainId: 421613,
    },
    arb: {
      url: 'https://arb-mainnet.g.alchemy.com/v2/'+`${alchemy_APIKEY}`,
      accounts: [`0x${AURORA_PRIVATE_KEY}`],
      chainId: 42161,
    },
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${alchemy_APIKEY}`,
      accounts: [`0x${AURORA_PRIVATE_KEY}`],
      chainId: 5,
    },
    testnet_aurora: {
      url: 'https://testnet.aurora.dev',
      accounts: [`0x${AURORA_PRIVATE_KEY}`],
      chainId: 1313161555,
    },
    local_aurora: {
      url: 'http://localhost:8545',
      accounts: [`0x${AURORA_PRIVATE_KEY}`],
      chainId: 1313161555,
      gasPrice: 120 * 1000000000
    },
  }
};
