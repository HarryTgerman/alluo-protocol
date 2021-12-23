// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./StablePool.sol";
import "./ERC20.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AlluoLp is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public poolAdress;

    constructor() ERC20("AlluoLP", "ALP") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        
        _beforeTokenTransfer(address(0), to, amount);

        _mint(to, amount);

        _afterTokenTransfer(address(0), to, amount);

    }

    function safeMint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address account, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override 
    {
        StablePool(poolAdress).claim(from);
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        //console.log("after");
        StablePool(poolAdress).claim(to);
        super._afterTokenTransfer(from, to, amount);
    }

    function setPoolAddress(address _newAddress) public{
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "AlluoToken: must have admin role"
        );
        poolAdress = _newAddress;
    }
}