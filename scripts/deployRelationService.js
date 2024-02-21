const {ethers, upgrades} = require("hardhat");

async function main() {
  const [owner] = await ethers.getSigners();

    const contractName = "RelationService";
    console.log(contractName)

    const MyContract = await ethers.getContractFactory(contractName);
    const myContract = await upgrades.deployProxy(MyContract,
        [owner.address],
        {unsafeAllowLinkedLibraries: true});

    await myContract.deployed();
    // const myContract = await MyContract.deploy();
    await myContract.deployTransaction.wait();
    console.log(
        `${contractName} deployed ,contract address: ${myContract.address}`
    );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });