import hre from "hardhat";

const { ethers } = await hre.network.connect();

async function main() {
  const contract = await ethers.deployContract("MilestoneFunding");
  await contract.waitForDeployment();

  console.log("MilestoneFunding deployed to:", await contract.getAddress());
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
