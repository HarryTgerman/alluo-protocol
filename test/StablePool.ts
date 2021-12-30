import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Contract, ContractFactory } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { parseEther } from '@ethersproject/units';
import { AlluoLp, AlluoLp__factory, IERC20, StablePool, StablePool__factory,  LiquidityBufferVault, LiquidityBufferVault__factory, FarmingVault, FarmingVault__factory } from '../typechain';


let TestDAI: ContractFactory;
let testDAI: IERC20;

let lpToken: AlluoLp;

let stablePool: StablePool;

let liquidityBufferVault: LiquidityBufferVault;
let farmingVault: FarmingVault;

let addr: Array<SignerWithAddress>;

let deployer: SignerWithAddress;
let addr1: SignerWithAddress;
let addr2: SignerWithAddress;
let addr3: SignerWithAddress;
let bigHolder: SignerWithAddress;
let strategy: SignerWithAddress;
let strategyLoss: SignerWithAddress;

async function skipDays(d: number){
    ethers.provider.send('evm_increaseTime', [d * 86400]);
    ethers.provider.send('evm_mine', []);
}

describe('StablePool contract', function (){
    
    beforeEach(async function () {
        [...addr] = await ethers.getSigners();
        deployer = addr[0];
        addr1 = addr[1];
        addr2 = addr[2];
        addr3 = addr[3];
        bigHolder = addr[4];
        strategy = addr[5];
        strategyLoss = addr[20];

        TestDAI = await ethers.getContractFactory('TestToken');
        testDAI = await TestDAI.deploy() as IERC20;   
        
        const LpToken = await ethers.getContractFactory('AlluoLp') as AlluoLp__factory;
        lpToken = await LpToken.deploy() as AlluoLp; 

        const StablePool = await ethers.getContractFactory('StablePool') as StablePool__factory;
        stablePool = await StablePool.deploy(testDAI.address) as StablePool;
        await stablePool.setLpToken(lpToken.address)

        lpToken.setPoolAddress(stablePool.address);
        lpToken.grantRole(await lpToken.MINTER_ROLE(), stablePool.address);
        lpToken.grantRole(await lpToken.BURNER_ROLE(), stablePool.address);
        lpToken.grantRole(await lpToken.ADMIN_ROLE(), stablePool.address);

        const LiquidityBufferVault = await ethers.getContractFactory('LiquidityBufferVault') as LiquidityBufferVault__factory;
        const FarmingVault = await ethers.getContractFactory('FarmingVault') as FarmingVault__factory;
        liquidityBufferVault = await LiquidityBufferVault.deploy() as LiquidityBufferVault; 
        farmingVault = await FarmingVault.deploy(testDAI.address) as FarmingVault; 

        liquidityBufferVault.setPool(stablePool.address);
        farmingVault.setPool(stablePool.address);

        stablePool.setBufferVaultAddress(liquidityBufferVault.address);
        stablePool.setFarmingVaultAddress(farmingVault.address);

        testDAI.transfer(addr1.address, parseEther('1000'))
        testDAI.transfer(addr2.address, parseEther('1000'))
        testDAI.transfer(addr3.address, parseEther('1000'))
        testDAI.transfer(bigHolder.address, parseEther('10000'))

        for(let i = 6; i < 15; i ++){                
            testDAI.transfer(addr[i].address, parseEther('500'))
            testDAI.connect(addr[i]).approve(stablePool.address, parseEther('500'))
        }   

        testDAI.connect(addr1).approve(stablePool.address, parseEther('1000'))
        testDAI.connect(addr2).approve(stablePool.address, parseEther('1000'))
        testDAI.connect(addr3).approve(stablePool.address, parseEther('1000'))
        testDAI.connect(bigHolder).approve(stablePool.address, parseEther('10000'))

        farmingVault.giveApprove(testDAI.address, strategy.address);
        farmingVault.giveApprove(testDAI.address, stablePool.address);
        liquidityBufferVault.giveApprove(testDAI.address, stablePool.address);
    });

    describe('Full cycle', function () {
        it('everything must be ok', async function () {
            for(let i = 0; i < 10; i ++){                
                await stablePool.connect(bigHolder).deposit(parseEther('1000'));
            }   
            //console.log((await testDAI.balanceOf(farmingVault.address)).toString());
            //9569,160997732421875000
            //console.log((await testDAI.balanceOf(liquidityBufferVault.address)).toString());
            //430,839002267578125000
            await stablePool.connect(addr[6]).deposit(parseEther('40'));
            //console.log((await testDAI.balanceOf(liquidityBufferVault.address)).toString());
            //470,839002267578125000     
            await stablePool.connect(addr1).deposit(parseEther('300'));
            expect(await lpToken.balanceOf(addr1.address)).to.equal(parseEther('300'));
            await lpToken.connect(addr1).transfer(addr2.address, parseEther('100'))
            await lpToken.connect(addr1).transfer(addr3.address, parseEther('100'))
            expect(await lpToken.balanceOf(addr2.address)).to.equal(parseEther('100'));
            await stablePool.connect(addr3).withdraw(parseEther('100'));
            expect(await testDAI.balanceOf(addr3.address)).to.equal(parseEther('1100'));

            //console.log((await testDAI.balanceOf(liquidityBufferVault.address)).toString());
            //console.log((await testDAI.balanceOf(farmingVault.address)).toString());
            //378,458049886621093750
            //9861,541950113378906250
            await stablePool.connect(bigHolder).withdraw(parseEther('500'));
            //console.log((await testDAI.balanceOf(liquidityBufferVault.address)).toString());
            //console.log((await testDAI.balanceOf(farmingVault.address)).toString());
            //0
            //9740,000000000000000000
            await stablePool.connect(bigHolder).withdraw(parseEther('500'));
            //console.log((await testDAI.balanceOf(farmingVault.address)).toString());
            //9240,000000000000000000

        });

    });
    // describe('Start', function () {
    //     it('should mint lp to ', async function () {

    //         await stablePool.connect(addr1).deposit(parseEther('100'));
    //         expect(await lpToken.balanceOf(addr1.address)).to.equal(parseEther('100'));

    //         expect(await testDAI.balanceOf(farmingVault.address)).to.equal(parseEther('100'));
    //         expect(await testDAI.balanceOf(farmingVault.address)).to.equal(await farmingVault.getBalance());

    //         expect(await testDAI.balanceOf(liquidityBufferVault.address)).to.equal(parseEther('0'));

    //         await testDAI.connect(strategy).transferFrom(farmingVault.address,strategy.address, parseEther('50'))
    //         //await stablePool.connect(addr2).deposit(parseEther('100'));
    //         await skipDays(73);
            
    //         await stablePool.setInterest(15);
    //         await stablePool.connect(addr1).deposit(parseEther('100'));
    //         await stablePool.connect(addr2).deposit(parseEther('100'));

    //         await skipDays(73);

    //         await stablePool.setInterest(8);
    //         await stablePool.connect(addr3).deposit(parseEther('100'));
    //         await stablePool.connect(bigHolder).deposit(parseEther('100'));

    //         await skipDays(73);

    //         await stablePool.setInterest(10);
    //         await stablePool.connect(bigHolder).deposit(parseEther('100'));

    //         await skipDays(73);
    //         await stablePool.connect(addr3).claim(addr3.address);
    //         console.log((await lpToken.balanceOf(addr3.address)).toString());

    //         await stablePool.setInterest(5);
    //         await stablePool.connect(bigHolder).deposit(parseEther('100'));

    //         await skipDays(73);

    //         await stablePool.connect(addr1).claim(addr1.address);
    //         console.log((await lpToken.balanceOf(addr1.address)).toString());
            
    //         await stablePool.connect(addr2).claim(addr2.address);
    //         console.log((await lpToken.balanceOf(addr2.address)).toString());

    //         await stablePool.connect(bigHolder).claim(bigHolder.address);
    //         console.log((await lpToken.balanceOf(bigHolder.address)).toString());
    //     });

    // });

    // describe('Start', function () {
    //     it('should mint lp tokens', async function () {

    //         await stablePool.connect(addr1).deposit(parseEther('100'));
    //         for(let i = 0; i < 365*10; i ++){
    //             await ethers.provider.send('evm_increaseTime', [60*60*24]);
    //             await ethers.provider.send('evm_mine', []);
    //             await stablePool.connect(addr1).claim(addr1.address);
    //         }
    //         console.log((await lpToken.balanceOf(addr1.address)).toString());
            
    //     });

    // });
  

});
  