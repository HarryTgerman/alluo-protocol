// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./../interface/IHarvestVault.sol";
import "./../interface/IHarvestPool.sol";

contract HarvestStrategy {
    using SafeERC20 for IERC20;

    uint256 public constant UINT256_MAX_VALUE =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    IERC20 public constant USDC =
        IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IHarvestVault public constant VAULT =
        IHarvestVault(0xeA4Eca0FbeB0fcAaE61D2fA2B2877d435FAEee1C);
    IHarvestPool public constant POOL =
        IHarvestPool(0xe7c9D242137896741b70CEfef701bBB4DcB158ec);

    constructor() {
        USDC.safeApprove(address(VAULT), UINT256_MAX_VALUE);
        USDC.safeApprove(address(POOL), UINT256_MAX_VALUE);

        IERC20(address(POOL)).safeApprove(address(VAULT), UINT256_MAX_VALUE);
    }

    function invest(uint256 amount) public {
        USDC.safeTransferFrom(msg.sender, address(this), amount);

        uint256 lpBefore = POOL.balanceOf(address(this));
        POOL.deposit(amount);
        uint256 lpAfter = POOL.balanceOf(address(this));

        lpBefore = VAULT.balanceOf(address(this));
        VAULT.stake(lpAfter - lpBefore);
        lpAfter = VAULT.balanceOf(address(this));

        IERC20(address(VAULT)).safeTransfer(msg.sender, lpAfter - lpBefore);
    }

    function unwind(uint256 lpAmount) public returns (uint256) {
        IERC20(address(VAULT)).safeTransferFrom(
            msg.sender,
            address(this),
            lpAmount
        );

        uint256 lpBefore = POOL.balanceOf(address(this));
        POOL.withdraw(lpAmount);
        uint256 lpAfter = POOL.balanceOf(address(this));

        VAULT.withdraw(lpAfter - lpBefore);

        // TO-DO - verify is this correct or not?? unfinished

        return 0;
    }

    function doWork() external {
        unwind(VAULT.balanceOf(address(this)));
        invest(USDC.balanceOf(address(this)));
    }
}
