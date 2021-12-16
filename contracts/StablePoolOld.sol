// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./AlluoLp.sol";
import "hardhat/console.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract StablePoolOld is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address public  DAItest;

    mapping(address => uint256) public last;

    uint256 public s;
    uint256 public lastSUpdate;
    
    // constant for percent calculation
    uint256 public constant DENOMINATOR = 1_000_000_000_000_000;
    uint32 public constant YEAR = 31536000;
    uint8 public interest = 8;

    address public lpToken;


    constructor(address _token, address _daiTest) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        lpToken = _token;
        DAItest = _daiTest;
        update();
    }

    function update() public{
        s += interest * DENOMINATOR * (block.timestamp - lastSUpdate);
        lastSUpdate = block.timestamp;
        //console.log(s);
    }

    function deposit(uint256 _amount) public{
        update();
        IERC20(DAItest).transferFrom(msg.sender, address(this), _amount);
        if(AlluoLp(lpToken).balanceOf(msg.sender) != 0){
            claim(msg.sender);
        }
        AlluoLp(lpToken).mint(msg.sender, _amount);
        last[msg.sender] = s;
    }

    function claim(address _address) public{
        update();
        if(last[_address] != 0){
            uint256 reward = ((s - last[_address]) * AlluoLp(lpToken).balanceOf(_address)) / (DENOMINATOR * 100 * YEAR);
            AlluoLp(lpToken).mint(_address, reward);
        }
        last[_address] = s;
    }

    function withdraw(uint256 _amount) public nonReentrant{
        claim(msg.sender);
        AlluoLp(lpToken).burn(msg.sender, _amount);
        IERC20(DAItest).transfer(msg.sender, _amount);
        last[msg.sender] = s;
    }

    function setInterest(uint8 _newInterest) public onlyRole(ADMIN_ROLE){
        update();
        interest = _newInterest;
        update();
    }
}
