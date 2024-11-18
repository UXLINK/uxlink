const hre = require("hardhat");
async function main() {

    UXContract = await ethers.getContractFactory("UXLINKTokenRewardPoolMultiple");
    uxContract = await UXContract.deploy();
    await uxContract.deployed();
    console.log("uxContract contract deployed at:", uxContract.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
