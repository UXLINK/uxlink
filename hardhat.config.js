require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");

/** @type import('hardhat/config').HardhatUserConfig */
require("dotenv").config();

/**
 *
 *  PRIVATE_KEY
 *
 *	•	Enter your Ethereum wallet private key here.
 *	•	Make sure to keep your private key secure to avoid any leaks.
 *	•	Format: PRIVATE_KEY=your-wallet-private-key.
 *
 *  alchemyNetworkUrl
 *
 *	•	Enter the node URL provided by Alchemy, which is used to connect to the Arbitrum Goerli testnet.
 *	•	Register with Alchemy to obtain the appropriate URL.
 *
 *  Visit Alchemy’s official website.
 *  Create an account and log in.
 *  Create a new app in the Alchemy dashboard and select the network as Arbitrum Goerli.
 *	Obtain the API Key for the app and construct the full node URL (e.g., https://arb-goerli.alchemyapi.io/v2/your-api-key).
 *	Fill the URL into the alchemyNetworkUrl variable.
 **/

const PRIVATE_KEY = "your-wallet-private-key";

const alchemyNetworkUrl = "https://arb-goerli.alchemyapi.io/v2/your-api-key";

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
        version: "0.8.21",
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
      arbitrumGoerli: PRIVATE_KEY,
    },
  },
  networks: {
    arb_goerli: {
      url: alchemyNetworkUrl,
      accounts: [`0x${PRIVATE_KEY}`],
      chainId: 421614, // arb arb-goerli chainId
    },
  },
};
