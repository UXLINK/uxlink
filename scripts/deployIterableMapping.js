// global scope, and execute the script.
// IterableMapping 是 UXGroupShares 的依赖 lib 
const hre = require("hardhat");

async function main() {
  // https://goerli.arbiscan.io/address/0x0002d863Ab8d7f5704d4c0279DC5D5aC9b7A821d#code
  IterableMapping = await ethers.getContractFactory("IterableMapping");
  iterableMapping = await IterableMapping.deploy();
  await iterableMapping.deployed();
  console.log("Pass this address to UXGroupShares contract,  IterableMapping contract deployed at:", iterableMapping.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
