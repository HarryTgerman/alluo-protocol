import { ethers, upgrades } from "hardhat"

async function main() {
  const adminAddress = "0xD61CbD5e5B513182E57fae1580411F8520f4e53E";
  const rewardPerDistribution = 0;
  const startTime = 1643885915; //example
  const distrbutionTime = 86400;
  const lockingToken = "0xe9c7ce45b669ba6fa48c29332367f61abfceee6c"
  const rewardToken = "0x1e2bfca2afdd7cdce56d9b91043317596f8b4942"

  const Locker = await ethers.getContractFactory("AlluoLocked");
  const locker = await upgrades.deployProxy(Locker,
    [adminAddress,
    rewardPerDistribution,
    startTime,
    distrbutionTime,
    lockingToken,
    rewardToken],
    {initializer: 'initialize', kind:'uups'}
)
  console.log("Alluo locker deployed to:", locker.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });