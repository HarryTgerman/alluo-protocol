// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";


contract Vault is AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 private balance;
    address public poolAddress;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
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
}