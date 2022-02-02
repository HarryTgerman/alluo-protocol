import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { BigNumber } from 'ethers';
import { Contract, ContractFactory } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { parseEther } from "@ethersproject/units";
import { keccak256 } from "ethers/lib/utils";
import { AlluoLocked, AlluoToken } from '../typechain';

import { Event } from "@ethersproject/contracts";


let Token: ContractFactory;
let lockingToken: AlluoToken;
let rewardToken: AlluoToken;

let Locker: ContractFactory;
let locker: AlluoLocked;

let addr: Array<SignerWithAddress>;

let rewardPerDistribution: BigNumber = parseEther("86400");
let startTime: number;
let distrbutionTime: number = 86400;

async function getTimestamp() {
    return (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp;
}

async function skipDays(days: number){
    ethers.provider.send("evm_increaseTime", [days * 86400]);
    ethers.provider.send("evm_mine", []);
}

async function shiftToStart(){
    ethers.provider.send("evm_setNextBlockTimestamp", [startTime]);
    ethers.provider.send("evm_mine", []);
}

describe("Locking contract", function () {

    beforeEach(async function () {
        startTime = await getTimestamp() + 150;
        //console.log("startTime: " + startTime);

        addr = await ethers.getSigners();

        Token = await ethers.getContractFactory("AlluoToken");
        lockingToken = await Token.deploy(addr[0].address) as AlluoToken;
        rewardToken = await Token.deploy(addr[0].address) as AlluoToken;

        Locker = await ethers.getContractFactory("AlluoLocked");


        locker = await upgrades.deployProxy(Locker,
            [rewardPerDistribution,
            startTime,
            distrbutionTime,
            lockingToken.address,
            rewardToken.address],
            {initializer: 'initialize', kind:'uups'}
        ) as AlluoLocked;

            await lockingToken.mint(addr[0].address, parseEther("100000"))
            await rewardToken.mint(addr[0].address, parseEther("1000000"))

            await lockingToken.transfer(addr[1].address, parseEther("2500"));
            await lockingToken.transfer(addr[2].address, parseEther("7000"));
            await lockingToken.transfer(addr[3].address, parseEther("3500"));
            await lockingToken.transfer(addr[4].address, parseEther("35000"));
     
            await rewardToken.connect(addr[0]).approve(locker.address, parseEther("1000000"));
     
            await locker.addReward(parseEther("1000000"))
     
            await lockingToken.connect(addr[1]).approve(locker.address, parseEther("2500"));
            await lockingToken.connect(addr[2]).approve(locker.address, parseEther("7000"));
            await lockingToken.connect(addr[3]).approve(locker.address, parseEther("3500"));
            await lockingToken.connect(addr[4]).approve(locker.address, parseEther("35000"));
    });
    describe("Basic functionality", function () {

        it("Should return info about vlAlluo", async function () {
            expect(await locker.name()).to.equal("Vote Locked Alluo Token"),
            expect(await locker.symbol()).to.equal("vlAlluo"),
            expect(await locker.decimals()).to.equal(18);
        });
        it("Should not allow to lock before start", async function () {
            await expect(locker.connect(addr[1]).lock(parseEther("1000"))
            ).to.be.revertedWith("Locking: locking time has not come yet");
        });
        it("Should allow lock/unlock + withdraw", async function () {
            await shiftToStart();

            await locker.update();
            await locker.connect(addr[1]).lock(parseEther("1000"));
            await skipDays(8);

            await expect(locker.connect(addr[1]).withdraw()
            ).to.be.revertedWith("Locking: Not enough tokens to unlock");
            await expect(locker.connect(addr[2]).unlockAll()
            ).to.be.revertedWith("Locking: Not enough tokens to unlock");

            await locker.connect(addr[1]).claimAndUnlock();
            
            await expect(locker.connect(addr[1]).withdraw()
            ).to.be.revertedWith("Locking: Unlocked tokens are not available yet");

            await skipDays(6);
            await locker.connect(addr[1]).withdraw();
        });
        it("Should allow unlock specified amount", async function () {
            await shiftToStart();

            await locker.connect(addr[1]).lock(parseEther("1000"));
            await skipDays(7);
            
            await locker.connect(addr[1]).unlock(parseEther("500"));

            await skipDays(6);
            await locker.connect(addr[1]).withdraw();
            expect(await lockingToken.balanceOf(addr[1].address)).to.equal(parseEther("2000"));

        });

        it("Should not allow unlock amount higher then locked", async function () {
            await shiftToStart();

            await locker.connect(addr[1]).lock(parseEther("1000"));
            await skipDays(7);

            await expect(locker.connect(addr[1]).unlock(parseEther("1500"))
            ).to.be.revertedWith("Locking: Not enough tokens to unlock");

        });

        it("Should not allow claim 0 amount", async function () {
            await shiftToStart();
            await expect(locker.connect(addr[2]).claim()
            ).to.be.revertedWith("Locking: Nothing to claim");
        });


        it("Should return right amount locked tokens after lock/unlock", async function () {
            await shiftToStart();

            let amount = parseEther("1000");

            await locker.connect(addr[1]).lock(amount);
            await skipDays(7);
            expect(await locker.balanceOf(addr[1].address)).to.equal(amount);

            amount = parseEther("500")
            await locker.connect(addr[1]).unlock(amount);

            expect(await locker.totalSupply()).to.equal(parseEther("1000"));

            
            expect(await locker.balanceOf(addr[1].address)).to.equal(amount);

            await skipDays(15);
            await locker.connect(addr[1]).withdraw();
            expect(await locker.balanceOf(addr[1].address)).to.equal(amount);
        });

    });
    describe("Reward calculation", function () {

        it("If there only one locker all rewards will go to him", async function () {
  
            await shiftToStart();

            await locker.connect(addr[1]).lock(parseEther("1000"));
            await skipDays(1);

            let claim = await locker.getClaim(addr[1].address);
            //console.log(claim.toString());

            expect(claim).to.be.gt(parseEther("86400"));
            expect(claim).to.be.lt(parseEther("86402"));

            await skipDays(1);

            await locker.connect(addr[1]).claim();
            claim = await rewardToken.balanceOf(addr[1].address);
            //console.log(claim.toString());

            expect(claim).to.be.gt(parseEther("172800"));
            expect(claim).to.be.lt(parseEther("172804")); 
        });
        it("If there are two lockers rewards are distributed between them", async function () {
  
            await shiftToStart();

            await locker.connect(addr[1]).lock(parseEther("1000"));
            await locker.connect(addr[2]).lock(parseEther("1000"));
            await skipDays(1);

            let claim = await locker.getClaim(addr[1].address);
            //console.log(claim.toString());

            expect(claim).to.be.gt(parseEther("43200"));
            expect(claim).to.be.lt(parseEther("43203"));

            await skipDays(1);

            await locker.connect(addr[2]).claim();
            claim = await rewardToken.balanceOf(addr[2].address);
            //console.log(claim.toString());

            expect(claim).to.be.gt(parseEther("86400"));
            expect(claim).to.be.lt(parseEther("86401"));
        });
        it("Full cycle with 4 lockers, different amount and time", async function () {
  
            await shiftToStart();
            // 1 day
            await locker.connect(addr[1]).lock(parseEther("1000"));
            await skipDays(1);
            // 2 day
            let claim = await locker.getClaim(addr[1].address);
            expect(claim).to.be.gt(parseEther("86400"));
            expect(claim).to.be.lt(parseEther("86402"));

            await locker.connect(addr[2]).lock(parseEther("2000"));
            await skipDays(1);
            // 3 day
            claim = await locker.getClaim(addr[1].address);
            expect(claim).to.be.gt(parseEther("115200"));
            expect(claim).to.be.lt(parseEther("115203"));

            await locker.connect(addr[3]).lock(parseEther("2500"));
            await skipDays(1);
            // 4 day
            claim = await locker.getClaim(addr[1].address);
            expect(claim).to.be.gt(parseEther("130909"));
            expect(claim).to.be.lt(parseEther("130912"));

            await locker.connect(addr[1]).lock(parseEther("1500"));
            await locker.connect(addr[4]).lock(parseEther("5000"));
            await skipDays(1);
            // 5 day
            //console.log((await locker.getClaim(addr[1].address)).toString());
            await skipDays(1);
            // 6 day
            //console.log((await locker.getClaim(addr[1].address)).toString());
            await skipDays(1);
            // 7 day
            await locker.connect(addr[2]).lock(parseEther("5000"));
            await locker.connect(addr[3]).lock(parseEther("1000"));
            await skipDays(1);
            // 8 day
            //console.log((await locker.getClaim(addr[1].address)).toString());
            await locker.connect(addr[4]).lock(parseEther("30000"));
            await skipDays(1);
            // 9 day
            //console.log((await locker.getClaim(addr[1].address)).toString());
            await skipDays(2);
            //end of 10 day
            console.log((await locker.getClaim(addr[1].address)).toString());
            console.log((await locker.getClaim(addr[2].address)).toString());
            console.log((await locker.getClaim(addr[3].address)).toString());
            console.log((await locker.getClaim(addr[4].address)).toString());
            
        });

    });

});