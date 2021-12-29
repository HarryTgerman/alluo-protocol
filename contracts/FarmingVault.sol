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

    struct Strategy{
        address sAddress;
        uint256 sBalance;
        uint256 sPercent;
        uint256 sDF;
    }

    Strategy[] strategies;

    uint256[] activeStrategies;

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
        strategy.sBalance = (DF * strategy.sBalance / strategy.sDF);
        strategy.sDF = DF;
    }

    function distribute(uint256 _amount) public onlyRole(ADMIN_ROLE){
        update();
        // for (uint256 i = 0; i < lastStrategy; i++) {
        //     if(strategies[i].sPercent != 0){
        //         //gives money
        //         //calculates advAPY
                
        //     }
        // }
    }

    function addStrategy(address _strategyAddress) public onlyRole(ADMIN_ROLE){
        strategies.push(Strategy({
            sAddress: _strategyAddress,
            sBalance: 0,
            sPercent: 0,
            sDF: 0
        }));
    }

    function setActiveStrategies(uint256[] memory _ids, uint256[] memory _percent) public onlyRole(ADMIN_ROLE){
        require(_ids.length == _percent.length);
        for (uint256 i = 0; i < _ids.length; i++) {
            strategies[_ids[i]];
        }
    }

    function callStrategiesForHelp(uint _amount) public onlyRole(ADMIN_ROLE){
        //takes money out of strategies
    }

    function changeInterestInStrategies(uint _newInterest) public onlyRole(ADMIN_ROLE){
        //
    }
}