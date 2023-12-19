// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { parseEther } from "ethers/lib/utils";
import { writeFileSync } from "fs";
import { ethers } from "hardhat";

async function main() {
  // Token
  const Token = await ethers.getContractFactory("SharkUSDC");
  // const token = await Token.deploy("SharkUSDC", "sUSDC");

  const collateralToken = await Token.deploy("CollateralToken", "CLTKN");

  // await token.deployed();
  await collateralToken.deployed();

  // const tokenData = JSON.stringify({
  //   address: token.address,
  //   abi: JSON.parse(token.interface.format("json") as string),
  // });
  // writeFileSync("./frontend/src/abis/Token.json", tokenData);

  // console.log("Token deployed to:", token.address);
  console.log("Collateral Token deployed to:", collateralToken.address);

  // LoanShark
  const LoanShark = await ethers.getContractFactory("LoanSharkToken");
  const loanshark = await LoanShark.deploy(
    "0x1AfE5e07f6c6f092494DA8423708c412939B6906",
    // token.address,
    collateralToken.address,
    parseEther("1000"), // Ratio
    parseEther("0.1") // Fees
  );

  await loanshark.deployed();

  const loansharkData = JSON.stringify({
    address: loanshark.address,
    abi: JSON.parse(loanshark.interface.format("json") as string),
  });
  writeFileSync("./frontend/src/abis/LoanSharkToken.json", loansharkData);

  console.log("LoanSharkToken deployed to:", loanshark.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
