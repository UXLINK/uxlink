const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contracts with the owner address:", deployer.address);

  const entryPointAddress = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789"; // eth-sepolia
  const uxlinkTokenAddress = "0xDaAD01cdcEC5318C7899AF31331564c6c3F3643c"; // eth-sepolia UXLINK TOKEN
  const wethAddress = "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14"; // eth-sepolia

  const initialTokenPrice = 5108 * (10**6);
  console.log(initialTokenPrice);

  // https://docs.uniswap.org/contracts/v3/reference/deployments/ethereum-deployments
  const quoterV2Address = "0xEd1f6473345F45b75F8179591dd5bA1888cf2FB3"; // eth-sepolia

  const UxPaymaster = await hre.ethers.getContractFactory("UXPaymaster");
  const paymaster = await UxPaymaster.deploy(entryPointAddress, uxlinkTokenAddress, wethAddress, quoterV2Address, initialTokenPrice);

  await paymaster.waitForDeployment();

  console.log("UxPaymaster deployed to:", paymaster.address);
  console.log("Deployment completed");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });