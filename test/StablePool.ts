import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, ContractFactory } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { parseEther } from "@ethersproject/units";


let TestDAI: ContractFactory;
let testDAI: Contract;

let LpToken: ContractFactory;
let lpToken: Contract;

let StablePool: ContractFactory;
let stablePool: Contract;

let Vault: ContractFactory;
let liquidityBufferVault: Contract;
let FarmingVault: Contract;

let deployer: SignerWithAddress;
let addr1: SignerWithAddress;
let addr2: SignerWithAddress;
let addr3: SignerWithAddress;
let addr4: SignerWithAddress;

async function skipDays(d: number){
    ethers.provider.send("evm_increaseTime", [d * 86400]);
    ethers.provider.send("evm_mine", []);
}

describe("StablePool contract", function (){
    
    beforeEach(async function () {
        [deployer, addr1, addr2, addr3, addr4] = await ethers.getSigners();

        TestDAI = await ethers.getContractFactory("TestToken");
        testDAI = await TestDAI.deploy();   
        
        LpToken = await ethers.getContractFactory("AlluoLp");
        lpToken = await LpToken.deploy(); 

        StablePool = await ethers.getContractFactory("StablePool");
        stablePool = await StablePool.deploy(lpToken.address, testDAI.address);

        lpToken.setPoolAddress(stablePool.address);
        lpToken.grantRole(await lpToken.MINTER_ROLE(), stablePool.address);
        lpToken.grantRole(await lpToken.BURNER_ROLE(), stablePool.address);
        lpToken.grantRole(await lpToken.ADMIN_ROLE(), stablePool.address);

        Vault = await ethers.getContractFactory("Vault");
        liquidityBufferVault = await Vault.deploy(); 
        FarmingVault = await Vault.deploy(); 

        liquidityBufferVault.setPool(stablePool.address);
        FarmingVault.setPool(stablePool.address);

        stablePool.setbufferVaultAddress(liquidityBufferVault.address);
        stablePool.setfarmingVaultAddress(FarmingVault.address);

        
        testDAI.transfer(addr1.address, parseEther("1000"))
        testDAI.transfer(addr2.address, parseEther("1000"))
        testDAI.transfer(addr3.address, parseEther("1000"))
        testDAI.transfer(addr4.address, parseEther("1000"))

        testDAI.connect(addr1).approve(stablePool.address, parseEther("1000"))
        testDAI.connect(addr2).approve(stablePool.address, parseEther("1000"))
        testDAI.connect(addr3).approve(stablePool.address, parseEther("1000"))
        testDAI.connect(addr4).approve(stablePool.address, parseEther("1000"))

    });

    describe("Start", function () {
        it("should mint lp to ", async function () {

            await stablePool.connect(addr1).deposit(parseEther("100"));
            // expect(await lpToken.balanceOf(addr1.address)).to.equal(parseEther('100'));
            // console.log((await lpToken.balanceOf(addr1.address)).toString());
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
  