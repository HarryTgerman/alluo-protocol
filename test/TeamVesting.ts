import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { ethers } from 'hardhat'
import { expect } from 'chai'

import { AlluoToken, AlluoToken__factory } from '../typechain'
import { parseEther } from '@ethersproject/units'
import { BigNumber } from '@ethersproject/bignumber'
import { TeamVesting } from '../typechain/TeamVesting'
import { TeamVesting__factory } from '../typechain/factories/TeamVesting__factory'


async function incrementNextBlockTimestamp(amount: number): Promise<void> {
    return ethers.provider.send("evm_increaseTime", [amount]);
}

async function getLatestBlockTimestamp(): Promise<BigNumber> {
    let bl_num = await ethers.provider.send("eth_blockNumber", []);
    let cur_block = await ethers.provider.send("eth_getBlockByNumber", [bl_num, false]);
    return BigNumber.from(cur_block.timestamp);
}

async function mine() {
    await ethers.provider.send("evm_mine", []);
}


describe('Contract: TeamVesting', () => {
    let accounts: SignerWithAddress[];
    let investorsVesting: TeamVesting;
    let token: AlluoToken;

    const cliffMonths = 6;
    const vestingMonthsCount = 24;
    const month = 2628000;

    before(async function () {
        accounts = await ethers.getSigners();
    });

    beforeEach(async function () {
        const deployer = accounts[0].address;

        let AcceptedToken = await ethers.getContractFactory('AlluoToken') as AlluoToken__factory;
        let InvestorsVesting = await ethers.getContractFactory("TeamVesting") as TeamVesting__factory;

        token = await AcceptedToken.deploy(deployer) as AlluoToken;
        investorsVesting = await InvestorsVesting.deploy(token.address) as TeamVesting;

        await investorsVesting.deployed();
        await token.deployed();
    });

    it("Should check that everything is initialized", async function () {
        expect(await investorsVesting.CLIFF_MONTHS()).to.be.equal(cliffMonths);
        expect(await investorsVesting.VESTING_MONTHS_COUNT()).to.be.equal(vestingMonthsCount);
        expect(await investorsVesting.MONTH()).to.be.equal(month);
    });

    it("Should add private user", async function () {
        const user = [accounts[1].address, accounts[2].address, accounts[3].address];
        const amount = [1000, 2000, 3000];
        const amountSum = amount.reduce((a, b) => a + b, 0);

        const totalAccumulatedBefore = await investorsVesting.totalTokensToPay();

        await token.mint(investorsVesting.address, amountSum)
        await investorsVesting.addPrivateUser(user, amount);

        for (let index = 0; index < user.length; index++) {
            expect((await investorsVesting.users(user[index])).accumulated).to.be.equal(amount[index]);
        }

        expect(await investorsVesting.totalTokensToPay()).to.be.equal(totalAccumulatedBefore.add(amountSum));
    });

    it("Should add private user (user re-add check)", async function () {
        const users = [accounts[1].address, accounts[2].address, accounts[3].address];
        const amounts = [parseEther("1000"), parseEther("2000"), parseEther("3000")];
        const amountsSum = parseEther("6000");

        await token.mint(investorsVesting.address, amountsSum);
        await investorsVesting.addPrivateUser(users, amounts);

        expect(await investorsVesting.totalTokensToPay()).to.be.equal(amountsSum);

        for (let index = 0; index < users.length; index++) {
            const user = users[index];
            const amount = amounts[index];

            const info = await investorsVesting.getUserInfo(user);

            expect(info.availableAmount).to.be.equal(0);
            expect(info.paidOut).to.be.equal(0);
            expect(info.totalAmountToPay).to.be.equal(amount);
        }

        const newAmounts = [parseEther("2000"), parseEther("3000"), parseEther("4000")];
        const newAmountsSum = parseEther("9000");

        await token.mint(investorsVesting.address, newAmountsSum.sub(amountsSum));
        await investorsVesting.addPrivateUser(users, newAmounts);

        expect(await investorsVesting.totalTokensToPay()).to.be.equal(newAmountsSum);

        for (let index = 0; index < users.length; index++) {
            const user = users[index];
            const amount = newAmounts[index];

            const info = await investorsVesting.getUserInfo(user);

            expect(info.availableAmount).to.be.equal(0);
            expect(info.paidOut).to.be.equal(0);
            expect(info.totalAmountToPay).to.be.equal(amount);
        }
    });

    it("Should not add private user (not owner)", async function () {
        const notAdmin = accounts[1];
        await expect(investorsVesting.connect(notAdmin).addPrivateUser([], [])).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should not add private user (no tokens on contract)", async function () {
        const account = accounts[1].address;
        const amount = parseEther("1000");

        // not sending any tokens
        await expect(investorsVesting.addPrivateUser([account], [amount])).to.be.revertedWith("Vesting: total tokens to pay exceed balance");
    });

    it("Should not add private user (some amount is zero)", async function () {
        const users = [accounts[1].address, accounts[2].address, accounts[3].address];
        const amounts = [parseEther("1000"), 0, parseEther("3000")];

        await expect(investorsVesting.addPrivateUser(users, amounts)).to.be.revertedWith("Vesting: some amount is zero");
    });

    it("Should get user info", async function () {
        const user = accounts[1].address;
        const amount = parseEther("1000");

        await token.mint(investorsVesting.address, amount)
        await investorsVesting.addPrivateUser([user], [amount]);

        const info = await investorsVesting.getUserInfo(user);

        expect(info.availableAmount).to.be.equal(0);
    });

    it("Should start vesting countdown", async function () {
        const user = accounts[0].address;
        const amount = parseEther("1000");

        await token.mint(investorsVesting.address, amount)
        await investorsVesting.addPrivateUser([user], [amount]);

        await investorsVesting.startCountdown([user]);
        const blockTimestamp = await getLatestBlockTimestamp();
        const startTime = blockTimestamp.add(month * cliffMonths);

        const userInfo = await investorsVesting.getUserInfo(user);

        expect(userInfo.isStarted).to.be.true;
        expect(userInfo.vestingStartTime).to.be.equal(startTime);
        expect(userInfo.vestingEndTime).to.be.equal(startTime.add(month * vestingMonthsCount));
    });

    it("Should not start vesting countdown (not owner)", async function () {
        const user = accounts[0].address;
        const amount = parseEther("1000");

        await token.mint(investorsVesting.address, amount)
        await investorsVesting.addPrivateUser([user], [amount]);

        const notOwner = accounts[1];
        await expect(investorsVesting.connect(notOwner).startCountdown([user])).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should not start vesting countdown (already started)", async function () {
        const user = accounts[0].address;
        const amount = parseEther("1000");

        await token.mint(investorsVesting.address, amount)
        await investorsVesting.addPrivateUser([user], [amount]);

        await investorsVesting.startCountdown([user]);
        await expect(investorsVesting.startCountdown([user])).to.be.revertedWith("Vesting: countdown is already started");
    });

    it("Should not start vesting countdown (unknown user)", async function () {
        const user = accounts[0].address;
        const unknownUser = accounts[1].address;
        const amount = parseEther("1000");

        await token.mint(investorsVesting.address, amount)
        await investorsVesting.addPrivateUser([user], [amount]);

        await expect(investorsVesting.startCountdown([user, unknownUser])).to.be.revertedWith("Vesting: unknown user");
    });

    it("Should claim no tokens (before vesting start)", async function () {
        const user = accounts[0].address;
        const amount = parseEther("1000");

        await token.mint(investorsVesting.address, amount)
        await investorsVesting.addPrivateUser([user], [amount]);
        await investorsVesting.startCountdown([user]);

        const userBalanceBeforeClaim = await token.balanceOf(user);
        await investorsVesting.claimToken();
        const userBalanceAfterClaim = await token.balanceOf(user);

        expect(userBalanceBeforeClaim).to.be.equal(userBalanceAfterClaim);
    });

    it("Should claim no tokens (before countdown start)", async function () {
        const user = accounts[0].address;
        const amount = parseEther("1000");

        await token.mint(investorsVesting.address, amount)
        await investorsVesting.addPrivateUser([user], [amount]);

        const userBalanceBeforeClaim = await token.balanceOf(user);
        await investorsVesting.claimToken();
        const userBalanceAfterClaim = await token.balanceOf(user);

        expect(userBalanceBeforeClaim).to.be.equal(userBalanceAfterClaim);
    });

    it("Should claim no tokens (unknown user)", async function () {
        const user = accounts[1];

        await expect(investorsVesting.connect(user).claimToken()).to.be.revertedWith("Vesting: not enough tokens to claim");
    });

    it("Should claim no tokens (already claimed everything)", async function () {
        const user = accounts[0].address;
        const amount = parseEther("1000");

        await token.mint(investorsVesting.address, amount);
        await investorsVesting.addPrivateUser([user], [amount]);
        await investorsVesting.startCountdown([user]);

        incrementNextBlockTimestamp((vestingMonthsCount + cliffMonths) * month);

        await investorsVesting.claimToken();
        await expect(investorsVesting.claimToken()).to.be.revertedWith("Vesting: not enough tokens to claim");
    });

    it("Should be able to claim tokens after vesting start", async function () {
        const user = accounts[0].address;
        const amount = parseEther("1000");

        await token.mint(investorsVesting.address, amount);
        await investorsVesting.addPrivateUser([user], [amount]);
        await investorsVesting.startCountdown([user]);

        await incrementNextBlockTimestamp((cliffMonths + (vestingMonthsCount / 2)) * month);
        await mine();

        const userBalanceBeforeClaim = await token.balanceOf(user);
        await investorsVesting.claimToken();
        const userBalanceAfterClaim = await token.balanceOf(user);
        const income = userBalanceAfterClaim.sub(userBalanceBeforeClaim);

        const blockTimestamp = await getLatestBlockTimestamp();
        const vestingStartTime = (await investorsVesting.getUserInfo(user)).vestingStartTime;

        const timeDiff = blockTimestamp.sub(vestingStartTime);

        const timeEarning = amount.mul(timeDiff).div(vestingMonthsCount * month);

        expect(income).to.be.equal(timeEarning);
    });

    it("Should check token reclaim", async function () {
        const user = accounts[0].address;
        const amount = parseEther("1000");

        await token.mint(investorsVesting.address, amount);
        await investorsVesting.addPrivateUser([user], [amount]);
        await investorsVesting.startCountdown([user]);

        await incrementNextBlockTimestamp((cliffMonths + (vestingMonthsCount / 4)) * month); // quater way
        await mine();

        const userBalanceBeforeFirstClaim = await token.balanceOf(user);
        await investorsVesting.claimToken(); // first immediate claim
        const userBalanceAfterFirstClaim = await token.balanceOf(user);
        const firstIncome = userBalanceAfterFirstClaim.sub(userBalanceBeforeFirstClaim);

        await incrementNextBlockTimestamp((cliffMonths + (vestingMonthsCount / 4)) * month); // half way
        await mine();

        const userBalanceBeforeSecondClaim = await token.balanceOf(user);
        await investorsVesting.claimToken(); // second claim after ~half period
        const userBalanceAfterSecondClaim = await token.balanceOf(user);
        const secondIncome = userBalanceAfterSecondClaim.sub(userBalanceBeforeSecondClaim);

        const blockTimestamp = await getLatestBlockTimestamp();
        const vestingStartTime = (await investorsVesting.getUserInfo(user)).vestingStartTime;

        const timeDiff = blockTimestamp.sub(vestingStartTime);

        const timeEarning = amount.mul(timeDiff).div(vestingMonthsCount * month);

        expect(firstIncome.add(secondIncome)).to.be.equal(timeEarning);
    });

    it("Should claim all user tokens (beyond vesting period)", async function () {
        const user = accounts[0].address;
        const amount = parseEther("1000");

        await token.mint(investorsVesting.address, amount);
        await investorsVesting.addPrivateUser([user], [amount]);
        await investorsVesting.startCountdown([user]);

        incrementNextBlockTimestamp((vestingMonthsCount + cliffMonths) * month + 1);
        await mine();

        const userBalanceBeforeClaim = await token.balanceOf(user);
        const viewAmount = await investorsVesting.getUserInfo(user);
        await investorsVesting.claimToken();
        const userBalanceAfterClaim = await token.balanceOf(user);

        expect(userBalanceAfterClaim).to.be.equal(userBalanceBeforeClaim.add(amount));
        expect(viewAmount.availableAmount).to.be.equal(userBalanceAfterClaim.sub(userBalanceBeforeClaim));
    });
})
