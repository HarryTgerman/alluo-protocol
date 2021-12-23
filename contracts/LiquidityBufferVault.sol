// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LiquidityBufferVault is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    //address public constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

    address public poolAddress;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    function setPool(address _pool) public onlyRole(DEFAULT_ADMIN_ROLE){
        poolAddress = _pool;
        grantRole(ADMIN_ROLE, poolAddress);
    }

    function giveApprove(address _token, address _recipient) public onlyRole(ADMIN_ROLE){
        IERC20(_token).safeApprove(_recipient, type(uint256).max);
    }
}