// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../strategy/AutofarmStrategy.sol";

contract FarmingVault is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    //address public constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address public  DAI;

    uint256 public DF = 10**20;

    // time of last DF update
    uint256 public lastDFUpdate;

    // time limit for using update
    uint256 public updateTimeLimit = 3600;

    // constant for percent calculation
    uint256 public constant DENOMINATOR = 10**20;

    // year in seconds
    uint32 public constant YEAR = 31536000;
    // current interest rate
    uint8 public interest = 8;

    uint256 private balance;
    address public poolAddress;
    address public apyBuffer;
    bool public farmingState;

    struct Strategy{
        address sAddress;
        uint256 minBalance;
        uint256 percent;
        uint256 DF;
        bool isAuto;
    }

    Strategy[] public strategies;

    uint256[] public activeStrategies;

    modifier isActive(){
        require(farmingState == true);
        _;
    }

    constructor(address _dai) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        DAI =_dai;
    }

    function getBalance() public view returns(uint256){
        return balance;
    }
    
    function setPool(address _pool) public onlyRole(DEFAULT_ADMIN_ROLE){
        poolAddress = _pool;
        grantRole(ADMIN_ROLE, poolAddress);
    }

    function giveApprove(address _token, address _recipient) public onlyRole(ADMIN_ROLE){
        IERC20(_token).safeApprove(_recipient, type(uint256).max);
    }

    function update() public{
        uint256 timeFromLastUpdate = block.timestamp - lastDFUpdate;
        if(timeFromLastUpdate <= lastDFUpdate + updateTimeLimit){
            DF = (DF * (interest * DENOMINATOR * timeFromLastUpdate / YEAR + 100 * DENOMINATOR) / DENOMINATOR) / 100;
            lastDFUpdate = block.timestamp;
        }
    }

    function claim(uint256 _id) public{
        Strategy storage strategy = strategies[_id];
        if(strategy.DF != 0){
            strategy.minBalance = (DF * strategy.minBalance / strategy.DF);
        }
        strategy.DF = DF;
    }

    function distribute(uint256 _amount) public onlyRole(ADMIN_ROLE) isActive{
        update();
        for(uint256 i = 0; i < activeStrategies.length; i++) {
            Strategy storage strategy = strategies[activeStrategies[i]];
            uint256 amount = _amount * strategy.percent / 100;
            claim(activeStrategies[i]);
            AutofarmStrategy(strategy.sAddress).invest(amount);
            strategy.minBalance += amount;
        }
        balance += _amount;
    }

    function callStrategiesForHelp(uint _amount) public onlyRole(ADMIN_ROLE) isActive{
        update();
        for(uint256 i = 0; i < activeStrategies.length; i++) {
            Strategy storage strategy = strategies[activeStrategies[i]];
            uint256 amount = _amount * strategy.percent / 100;
            claim(activeStrategies[i]);
            AutofarmStrategy(strategy.sAddress).unwind(amount);
            strategy.minBalance -= amount;
        }
        balance -= _amount;
    }

    function finishStrategies() public onlyRole(ADMIN_ROLE) isActive{
        update();
        uint256 totalMinBalance;
        for(uint256 i = 0; i < activeStrategies.length; i++) {
            Strategy storage strategy = strategies[activeStrategies[i]];
            uint256 amountReceived = AutofarmStrategy(strategy.sAddress).unwindAll();
            claim(activeStrategies[i]);
            totalMinBalance += strategy.minBalance;
            if(strategy.minBalance > amountReceived){
                createSlashingProposal();
            }
        }
        balance = totalMinBalance;
        splitExtra(IERC20(DAI).balanceOf(address(this)) - totalMinBalance);
        delete activeStrategies;
        farmingState = false;
    }

    function addStrategy(address _strategyAddress, bool _isAuto) public onlyRole(ADMIN_ROLE){
        strategies.push(Strategy({
            sAddress: _strategyAddress,
            minBalance: 0,
            percent: 0,
            DF: 0,
            isAuto: _isAuto
        }));
    }

    function setActiveStrategies(uint256[] memory _ids, uint256[] memory _percents) public onlyRole(ADMIN_ROLE){
        require(_ids.length == _percents.length);
        require(farmingState == false);
        for (uint256 i = 0; i < _ids.length; i++) {
            activeStrategies.push(_ids[i]);
            Strategy storage strategy = strategies[_ids[i]];
            strategy.minBalance = 0;
            strategy.percent = _percents[i];
        }
        farmingState = true;
        distribute(balance);
    }

    function splitExtra(uint256 _amount) internal{
        uint256 need = balance / 100;
        if(IERC20(DAI).balanceOf(apyBuffer) < need){
            if(need > _amount){
                IERC20(DAI).safeTransfer(apyBuffer, _amount);   
            }
            else{
                IERC20(DAI).safeTransfer(apyBuffer, need);   
                sendBalncer(_amount - need);
            }
        }
        else{
            sendBalncer(_amount);
        }
    }

    function changeInterestInStrategies(uint8 _newInterest) public onlyRole(ADMIN_ROLE){
        update();
        interest = _newInterest;
    }

    function createSlashingProposal() public onlyRole(ADMIN_ROLE){
    }

    function sendBalncer(uint256 _amount) internal{
    }
    
}