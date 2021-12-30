// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
    bool public active;

    uint256 all;

    struct Strategy{
        address sAddress;
        uint256 sBalance;
        uint256 sPercent;
        uint256 sDF;
    }

    Strategy[] public strategies;

    uint256[] public activeStrategies;

    modifier isActive(){
        require(active == true);
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

    function changeBalance(int256 _amount) public onlyRole(ADMIN_ROLE){
        balance = uint256(int256(balance) + _amount);
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
        if(strategy.sDF != 0){
            strategy.sBalance = (DF * strategy.sBalance / strategy.sDF);
        }
        strategy.sDF = DF;
    }

    function distribute(uint256 _amount) public onlyRole(ADMIN_ROLE) isActive{
        update();
        for(uint256 i = 0; i < activeStrategies.length; i++) {
            Strategy storage str = strategies[activeStrategies[i]];
            uint256 amount = _amount * str.sPercent / 100;
            claim(activeStrategies[i]);
            giveToStrategy(str.sAddress, amount);
            str.sBalance += amount;
        }
    }

    function finishStrategies() public onlyRole(ADMIN_ROLE) isActive{
        update();
        for(uint256 i = 0; i < activeStrategies.length; i++) {
            Strategy storage str = strategies[activeStrategies[i]];
            uint256 amountReceived = takeOutOfStrategy(str.sAddress, address(this), all);
            claim(activeStrategies[i]);
            if(str.sBalance > amountReceived){
                createSlashingProposal();
            }
        }
        balance = IERC20(DAI).balanceOf(address(this));
        delete activeStrategies;
        active = false;
    }

    function addStrategy(address _strategyAddress) public onlyRole(ADMIN_ROLE){
        strategies.push(Strategy({
            sAddress: _strategyAddress,
            sBalance: 0,
            sPercent: 0,
            sDF: 0
        }));
    }

    function setActiveStrategies(uint256[] memory _ids, uint256[] memory _percents) public onlyRole(ADMIN_ROLE){
        require(_ids.length == _percents.length);
        for (uint256 i = 0; i < _ids.length; i++) {
            activeStrategies.push(_ids[i]);
            Strategy storage str = strategies[_ids[i]];
            str.sBalance = 0;
            str.sPercent = _percents[i];
        }
        active = true;
        distribute(balance);
    }

    function callStrategiesForHelp(uint _amount) public onlyRole(ADMIN_ROLE){
        update();
        for(uint256 i = 0; i < activeStrategies.length; i++) {
            Strategy storage str = strategies[activeStrategies[i]];
            uint256 amount = _amount * str.sPercent / 100;
            claim(activeStrategies[i]);
            takeOutOfStrategy(str.sAddress, msg.sender, amount);
            str.sBalance -= amount;
        }
    }

    function changeInterestInStrategies(uint8 _newInterest) public onlyRole(ADMIN_ROLE){
        interest = _newInterest;
    }

    function createSlashingProposal() public onlyRole(ADMIN_ROLE){
    }
    
    function giveToStrategy(address _strategy, uint _amount) public onlyRole(ADMIN_ROLE){
       IERC20(DAI).transfer(_strategy, _amount);
    }

    function takeOutOfStrategy(address _strategy, address _to, uint _amount) public onlyRole(ADMIN_ROLE) returns(uint256) {
        IERC20(DAI).transferFrom(_strategy, _to, _amount);
    }
}