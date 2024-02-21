// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const {ethers, upgrades} = require("hardhat");


const name = 'UXLink Name Service V2';
const symbol = 'UXSBT';
const baseURI = '';

const minNameLength_ = 3;
const maxNameLength_ = 32;
const nameLengthControl = {"_nameLength": 3, "_maxCount": 1000};//means the maxCount of 3 characters is 1000
const suffix = ".uxlink";

async function main() {
    const [owner] = await ethers.getSigners();

    const contractName = "NameService";
    
    const MyContract = await ethers.getContractFactory(contractName);
    const myContract = await upgrades.deployProxy(MyContract,
        [owner.address,
            name,
            symbol,
            baseURI,],
        {unsafeAllowLinkedLibraries: true});

    await myContract.deployed();
    // const myContract = await MyContract.deploy();
    await myContract.deployTransaction.wait();
    console.log(
        `${contractName} deployed ,contract address: ${myContract.address}`
    );
    await (await myContract.setNameLengthControl(minNameLength_, maxNameLength_, nameLengthControl._nameLength, nameLengthControl._maxCount)).wait();
    await (await myContract.setSuffix(suffix)).wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
