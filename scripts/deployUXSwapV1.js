// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  UXSwapV1 = await ethers.getContractFactory("UXSwapV1");
  uXSwapV1 = await UXSwapV1.deploy();
  await uXSwapV1.deployed();
  console.log("UXSwapV1 contract deployed at:", uXSwapV1.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
