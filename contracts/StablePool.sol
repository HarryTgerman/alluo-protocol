// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "hardhat/console.sol";

import "./AlluoLp.sol";
import "./FarmingVault.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract StablePool is AccessControl, ReentrancyGuard{
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    //address public constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address public  DAI;
    
    // Debt factor: variable which grow after any action from user
    // based on current interest rate and time from last update call
    // this is a large number for a more accurate calculation
    uint256 public DF = 10**20;

    // time of last DF update
    uint256 public lastDFUpdate;

    // time limit for using update
    uint256 public updateTimeLimit = 3600;

    // DF of user from last user action on contract
    mapping(address => uint256) public userDF;

    // constant for percent calculation
    uint256 public constant DENOMINATOR = 10**20;

    // year in seconds
    uint32 public constant YEAR = 31536000;
    // current interest rate
    uint8 public interest = 8;

    // address of the token that we mint/burn in exchange for assets
    address public lpToken;

    address public bufferVaultAddress;
    address public farmingVaultAddress;

    //constructor(address _lpToken) {
    constructor(address _dai) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        DAI = _dai;
        lastDFUpdate = block.timestamp;
        update();
    }

    function update() public{
        uint256 timeFromLastUpdate = block.timestamp - lastDFUpdate;
        if(timeFromLastUpdate <= lastDFUpdate + updateTimeLimit){
            DF = (DF * (interest * DENOMINATOR * timeFromLastUpdate / YEAR + 100 * DENOMINATOR) / DENOMINATOR) / 100;
            lastDFUpdate = block.timestamp;
        }
    }

    function claim(address _address) public{
        update();
        if(userDF[_address] != 0 ){
            uint256 userBalance = AlluoLp(lpToken).balanceOf(_address);
            uint256 userNewBalance = (DF * userBalance / userDF[_address]);
            AlluoLp(lpToken).mint(_address, userNewBalance - userBalance);
        }
        userDF[_address] = DF;
    }

    function deposit(uint256 _amount) public{
        update();
        if(AlluoLp(lpToken).balanceOf(msg.sender) != 0){
            claim(msg.sender);
        }
        _deposit(_amount);
        AlluoLp(lpToken).mint(msg.sender, _amount);
        userDF[msg.sender] = DF;
    }

    function withdraw(uint256 _amount) public nonReentrant{
        claim(msg.sender);
        AlluoLp(lpToken).burn(msg.sender, _amount);
        _withdraw(_amount);
        userDF[msg.sender] = DF;
    }

    function _deposit(uint256 _amount) internal{
        uint256 remains = sendMissing(_amount);
        if(remains != 0){
            IERC20(DAI).safeTransferFrom(msg.sender, farmingVaultAddress, remains);
            FarmingVault(farmingVaultAddress).changeBalance(int256(remains));
            FarmingVault(farmingVaultAddress).distribute(remains);
        }
    }

    function _withdraw(uint256 _amount) internal{
        uint256 buffer = IERC20(DAI).balanceOf(bufferVaultAddress);
        uint256 farming = FarmingVault(farmingVaultAddress).getBalance();
        uint256 remains = _amount;
        if (buffer != 0){
            if(buffer > _amount){
                IERC20(DAI).safeTransferFrom(bufferVaultAddress, msg.sender, _amount);
                remains = 0;
            }
            else{
                IERC20(DAI).safeTransferFrom(bufferVaultAddress, msg.sender, buffer);
                remains -= buffer;
            }
        }
        if(remains != 0){
            if (farming > remains){
                FarmingVault(farmingVaultAddress).callStrategiesForHelp(remains);
                IERC20(DAI).safeTransferFrom(farmingVaultAddress, msg.sender, remains);
            }
            else{
                callDaoForHelp(remains);
            }
        }
    }

    function sendMissing(uint256 _amount) internal returns(uint256){
        uint256 missing = checkMissing();
        if(missing != 0){
            if(missing > _amount){
                IERC20(DAI).safeTransferFrom(msg.sender, bufferVaultAddress, _amount);
                return 0;
            }
            else{
                IERC20(DAI).safeTransferFrom(msg.sender, bufferVaultAddress, missing);
                return _amount - missing; 
            }
        }
        return _amount;
    }

    function checkMissing() internal view returns(uint256) {
        uint256 buffer = IERC20(DAI).balanceOf(bufferVaultAddress);
        uint256 farming = FarmingVault(farmingVaultAddress).getBalance();
        uint256 need = farming * 5 / 100;
        if(buffer < need ){
            return need - buffer;
        }
        else{
            return 0;
        }
    }

    function setInterest(uint8 _newInterest) public onlyRole(ADMIN_ROLE){
        update();
        interest = _newInterest;
        FarmingVault(farmingVaultAddress).changeInterestInStrategies(_newInterest);
    }

    function setLpToken(address _newToken) public onlyRole(ADMIN_ROLE){
        lpToken = _newToken;
    }

    function setBufferVaultAddress(address _newBuffer) public onlyRole(ADMIN_ROLE){
        bufferVaultAddress = _newBuffer;
    }

    function setFarmingVaultAddress(address _newFarming) public onlyRole(ADMIN_ROLE){
        farmingVaultAddress = _newFarming;
    }

    function callDaoForHelp(uint _amount) private {

    }
}