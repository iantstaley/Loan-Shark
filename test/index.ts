import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { formatEther, parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";
import { ERC20, LoanShark, LoanSharkToken } from "../typechain";

describe("Loan Shark Native Currency", function () {
  let token: ERC20,
    loanshark: LoanShark,
    account0: SignerWithAddress,
    account1: SignerWithAddress;

  this.beforeAll(async function () {
    [account0, account1] = await ethers.getSigners();

    const TokenFactory = await ethers.getContractFactory("SharkUSDC");
    token = await TokenFactory.deploy("SharkUSDC", "sUSD");

    await token.deployed();

    const SharkFactory = await ethers.getContractFactory("LoanShark");
    loanshark = await SharkFactory.deploy(token.address, parseEther("1000"), 0);

    await loanshark.deployed();

    token.transfer(loanshark.address, parseEther("100000"));
  });

  it("Borrow: Should transfer stablecoin in return for eth", async function () {
    const ratio = +formatEther(await loanshark.ratio());

    const amount = "1";

    // Borrow stablecoin with ETH
    await loanshark.connect(account1).borrow({
      value: parseEther(amount),
    });

    const tokenBalance = +formatEther(await token.balanceOf(account1.address));
    expect(tokenBalance).to.equal(+amount * ratio);
  });

  it("Repay: Should return ETH minus fees when returning stablecoin", async function () {
    const fee = +formatEther(await loanshark.fee());
    const ratio = +formatEther(await loanshark.ratio());

    const initialEthBalance = +formatEther(await account1.getBalance());

    const tokenAmount = "1000";
    await token
      .connect(account1)
      .approve(loanshark.address, ethers.constants.MaxUint256);
    await loanshark.connect(account1).repay(parseEther(tokenAmount));

    const finalEthBalance = +formatEther(await account1.getBalance());

    const finalEthAmount = (+tokenAmount / ratio - fee).toString();

    expect(finalEthBalance - initialEthBalance).to.closeTo(
      +finalEthAmount,
      0.1
    );
  });
});

///////// Loan Shark Token - Any ERC20 Token as Collateral
describe("Loan Shark Token", function () {
  let stablecoin: ERC20,
    collateralToken: ERC20,
    loanshark: LoanSharkToken,
    account0: SignerWithAddress,
    account1: SignerWithAddress;

  this.beforeAll(async function () {
    [account0, account1] = await ethers.getSigners();

    const TokenFactory = await ethers.getContractFactory("SharkUSDC");
    stablecoin = await TokenFactory.deploy("SharkUSDC", "sUSDC");

    await stablecoin.deployed();

    collateralToken = await TokenFactory.deploy("CollateralToken", "CTKN");

    await collateralToken.deployed();

    const SharkFactory = await ethers.getContractFactory("LoanSharkToken");
    loanshark = await SharkFactory.deploy(
      stablecoin.address,
      collateralToken.address,
      parseEther("1000"), // Ratio
      parseEther("0.1") // Fees from Collateral Token
    );

    await loanshark.deployed();

    stablecoin.transfer(loanshark.address, parseEther("100000"));
  });

  it("Borrow: Should transfer stablecoin in return for eth", async function () {
    const ratio = +formatEther(await loanshark.ratio());

    const amount = "1";
    const amountRaw = parseEther(amount);

    await collateralToken.transfer(account1.address, amountRaw);
    await collateralToken
      .connect(account1)
      .approve(loanshark.address, amountRaw);

    // Borrow stablecoin with CollateralToken. Amount passed is the collateral amount
    await loanshark.connect(account1).borrow(amountRaw);

    const tokenBalance = +formatEther(
      await stablecoin.balanceOf(account1.address)
    );
    expect(tokenBalance).to.equal(+amount * ratio);
  });

  it("Repay: Should return Collateral Token minus fees when returning stablecoin", async function () {
    const fee = +formatEther(await loanshark.fee());
    const ratio = +formatEther(await loanshark.ratio());

    const initialCollateralBalance = +formatEther(
      await collateralToken.balanceOf(account1.address)
    );

    // Since ratio is 1000 in these tests, must have borrowed 1000 at least for 1 collateral token
    const tokenAmount = "1000";

    await stablecoin
      .connect(account1)
      .approve(loanshark.address, ethers.constants.MaxUint256);
    await loanshark.connect(account1).repay(parseEther(tokenAmount));

    const finalCollateralBalance = +formatEther(
      await collateralToken.balanceOf(account1.address)
    );

    const finalCollateralAmount = (+tokenAmount / ratio - fee).toString();

    expect(finalCollateralBalance - initialCollateralBalance).to.closeTo(
      +finalCollateralAmount,
      0.1
    );

    // Collected Fees in Collateral Token
    const collectedFees = +formatEther(await loanshark.collectedFees());
    expect(collectedFees).to.equal(fee);
  });

  it("Should claim fees to the owner", async function () {
    // owner = account0
    const collectedFees = +formatEther(await loanshark.collectedFees());
    const ownerBalance0 = +formatEther(
      await collateralToken.balanceOf(account0.address)
    );

    await loanshark.claimFees();

    const ownerBalance1 = +formatEther(
      await collateralToken.balanceOf(account0.address)
    );
    const collectedFees1 = +formatEther(await loanshark.collectedFees());

    expect(collectedFees1).to.equal(0);
    expect(ownerBalance1 - ownerBalance0).to.closeTo(collectedFees, 0.01);
  });
});
