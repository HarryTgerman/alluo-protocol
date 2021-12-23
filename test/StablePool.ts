import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, ContractFactory } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { parseEther } from "@ethersproject/units";
import { AlluoLp, AlluoLp__factory, IERC20, StablePool, StablePool__factory,  LiquidityBufferVault, LiquidityBufferVault__factory, FarmingVault, FarmingVault__factory } from "../typechain";


let TestDAI: ContractFactory;
let testDAI: IERC20;

let lpToken: AlluoLp;

let stablePool: StablePool;

let liquidityBufferVault: LiquidityBufferVault;
let farmingVault: FarmingVault;

let deployer: SignerWithAddress;
let addr1: SignerWithAddress;
let addr2: SignerWithAddress;
let addr3: SignerWithAddress;
let addr4: SignerWithAddress;
let strategy: SignerWithAddress;

async function skipDays(d: number){
    ethers.provider.send("evm_increaseTime", [d * 86400]);
    ethers.provider.send("evm_mine", []);
}

describe("StablePool contract", function (){
    
    beforeEach(async function () {
        [deployer, addr1, addr2, addr3, addr4, strategy] = await ethers.getSigners();

        TestDAI = await ethers.getContractFactory("TestToken");
        testDAI = await TestDAI.deploy() as IERC20;   
        
        const LpToken = await ethers.getContractFactory("AlluoLp") as AlluoLp__factory;
        lpToken = await LpToken.deploy() as AlluoLp; 

        const StablePool = await ethers.getContractFactory("StablePool") as StablePool__factory;
        stablePool = await StablePool.deploy(lpToken.address, testDAI.address) as StablePool;

        lpToken.setPoolAddress(stablePool.address);
        lpToken.grantRole(await lpToken.MINTER_ROLE(), stablePool.address);
        lpToken.grantRole(await lpToken.BURNER_ROLE(), stablePool.address);
        lpToken.grantRole(await lpToken.ADMIN_ROLE(), stablePool.address);

        const LiquidityBufferVault = await ethers.getContractFactory("LiquidityBufferVault") as LiquidityBufferVault__factory;
        const FarmingVault = await ethers.getContractFactory("FarmingVault") as FarmingVault__factory;
        liquidityBufferVault = await LiquidityBufferVault.deploy() as LiquidityBufferVault; 
        farmingVault = await FarmingVault.deploy() as FarmingVault; 

        liquidityBufferVault.setPool(stablePool.address);
        farmingVault.setPool(stablePool.address);

        stablePool.setbufferVaultAddress(liquidityBufferVault.address);
        stablePool.setfarmingVaultAddress(farmingVault.address);

        testDAI.transfer(addr1.address, parseEther("1000"))
        testDAI.transfer(addr2.address, parseEther("1000"))
        testDAI.transfer(addr3.address, parseEther("1000"))
        testDAI.transfer(addr4.address, parseEther("1000"))

        testDAI.connect(addr1).approve(stablePool.address, parseEther("1000"))
        testDAI.connect(addr2).approve(stablePool.address, parseEther("1000"))
        testDAI.connect(addr3).approve(stablePool.address, parseEther("1000"))
        testDAI.connect(addr4).approve(stablePool.address, parseEther("1000"))

        farmingVault.giveApprove(testDAI.address, strategy.address);

    });

    describe("Start", function () {
        it("should mint lp to ", async function () {

            await stablePool.connect(addr1).deposit(parseEther("100"));
            expect(await lpToken.balanceOf(addr1.address)).to.equal(parseEther('100'));

            expect(await testDAI.balanceOf(farmingVault.address)).to.equal(parseEther('100'));
            expect(await testDAI.balanceOf(farmingVault.address)).to.equal(await farmingVault.getBalance());

            expect(await testDAI.balanceOf(liquidityBufferVault.address)).to.equal(parseEther('0'));

            await testDAI.connect(strategy).transferFrom(farmingVault.address,strategy.address, parseEther("50"))
            //await stablePool.connect(addr2).deposit(parseEther("100"));
            await skipDays(73);
            
            await stablePool.setInterest(15);
            await stablePool.connect(addr1).deposit(parseEther("100"));
            await stablePool.connect(addr2).deposit(parseEther("100"));

            await skipDays(73);

            await stablePool.setInterest(8);
            await stablePool.connect(addr3).deposit(parseEther("100"));
            await stablePool.connect(addr4).deposit(parseEther("100"));

            await skipDays(73);

            await stablePool.setInterest(10);
            await stablePool.connect(addr4).deposit(parseEther("100"));

            await skipDays(73);
            await stablePool.connect(addr3).claim(addr3.address);
            console.log((await lpToken.balanceOf(addr3.address)).toString());

            await stablePool.setInterest(5);
            await stablePool.connect(addr4).deposit(parseEther("100"));

            await skipDays(73);

            await stablePool.connect(addr1).claim(addr1.address);
            console.log((await lpToken.balanceOf(addr1.address)).toString());
            
            await stablePool.connect(addr2).claim(addr2.address);
            console.log((await lpToken.balanceOf(addr2.address)).toString());

            await stablePool.connect(addr4).claim(addr4.address);
            console.log((await lpToken.balanceOf(addr4.address)).toString());
        });

    });

    // describe("Start", function () {
    //     it("should mint lp tokens", async function () {

    //         await stablePool.connect(addr1).deposit(parseEther("100"));
    //         for(let i = 0; i < 365; i ++){
    //             await ethers.provider.send("evm_increaseTime", [60*60*24]);
    //             await ethers.provider.send("evm_mine", []);
    //             await stablePool.connect(addr1).claim(addr1.address);
    //         }
    //         console.log((await lpToken.balanceOf(addr1.address)).toString());
            
    //     });

    // });
  

});
  