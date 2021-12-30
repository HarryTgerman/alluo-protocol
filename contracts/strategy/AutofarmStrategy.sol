// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./../interface/ICurvePool.sol";
import "./../interface/IAutofarmStaking.sol";

contract AutofarmStrategy is Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant UINT256_MAX_VALUE =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    IERC20 public constant DAI =
        IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    IERC20 public constant USDC =
        IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 public constant USDT =
        IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);

    IERC20 public constant LPTOKEN =
        IERC20(0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171);

    ICurvePool public constant POOL =
        ICurvePool(0x445FE580eF8d70FF569aB36e80c647af338db351);

    IAutofarmStaking public constant STAKING =
        IAutofarmStaking(0x89d065572136814230A55DdEeDDEC9DF34EB0B76);

    uint8 public constant PID = 66;

    constructor(address farmingVault) {
        _transferOwnership(farmingVault);

        DAI.safeApprove(address(POOL), UINT256_MAX_VALUE);
        USDC.safeApprove(address(POOL), UINT256_MAX_VALUE);
        USDT.safeApprove(address(POOL), UINT256_MAX_VALUE);

        LPTOKEN.safeApprove(address(STAKING), UINT256_MAX_VALUE);
    }

    function invest(uint256 amount) external onlyOwner {
        DAI.safeTransferFrom(msg.sender, address(this), amount);

        uint256 lpAmount = POOL.add_liquidity([amount, 0, 0], 0, true);

        STAKING.deposit(PID, lpAmount);
    }

    function unwind(uint256 amount) external onlyOwner returns (uint256) {
        uint256 lpAvailible = STAKING.stakedWantTokens(PID, address(this));
        uint256 requiredLp = POOL.calc_token_amount([amount, 0, 0], false);

        require(requiredLp <= lpAvailible, "AutofarmStrategy: not enough LP");

        STAKING.withdraw(PID, requiredLp);
        uint256 daiAmount = POOL.remove_liquidity_one_coin(
            requiredLp,
            0,
            0,
            true
        );

        DAI.safeTransfer(msg.sender, daiAmount);

        return daiAmount;
    }

    function unwindAll() external onlyOwner returns (uint256) {
        uint256 lpAutofarm = STAKING.stakedWantTokens(PID, address(this));

        require(lpAutofarm > 0, "AutofarmStrategy: i'm empty");

        STAKING.withdraw(PID, lpAutofarm);

        uint256 daiAmount = POOL.remove_liquidity_one_coin(
            lpAutofarm,
            0,
            0,
            true
        );

        DAI.safeTransfer(msg.sender, daiAmount);

        return daiAmount;
    }
}
