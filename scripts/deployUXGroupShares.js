// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  // https://goerli.arbiscan.io/address/0x0002d863Ab8d7f5704d4c0279DC5D5aC9b7A821d#code
  // ## deploy IterableMapping first. Then deploy UXGroupShares contract.

  // 配置结算ERC20 TOKEN
  const settlementTokenAddress = "0xD3F8e7c3449906D689D022009453A7d72acEfc15";
  // 配置依赖库地址
  const iterableMappingAddress = "0x0002d863Ab8d7f5704d4c0279DC5D5aC9b7A821d";

  UXGroupShares = await ethers.getContractFactory("UXGroupShares",{
    libraries: {
      // IterableMapping: iterableMapping.address,
      IterableMapping: iterableMappingAddress,
    },
  });
  uxXGroupShares = await UXGroupShares.deploy(settlementTokenAddress);
  await uxXGroupShares.deployed();  
  console.log("UXGroupShares contract deployed at:", uxXGroupShares.address);

  // deploy 带参数，所以 verify 也需要带上参数
  // npx hardhat verify --network arb_goerli 0xA142CFBaeB6f274748b930dc100d5E99c3BCD23c "0xD3F8e7c3449906D689D022009453A7d72acEfc15"

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
