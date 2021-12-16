// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IHarvestVault {
    function addRewardToken(address rt) external;

    function allowance(address _owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function controller() external view returns (address);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);

    function duration() external view returns (uint256);

    function earned(address account) external view returns (uint256);

    function earned(address rt, address account)
        external
        view
        returns (uint256);

    function earned(uint256 i, address account) external view returns (uint256);

    function exit() external;

    function getAllRewards() external;

    function getReward() external;

    function getReward(address rt) external;

    function getRewardTokenIndex(address rt) external view returns (uint256);

    function governance() external view returns (address);

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    function lastTimeRewardApplicable(address rt)
        external
        view
        returns (uint256);

    function lastTimeRewardApplicable() external view returns (uint256);

    function lastTimeRewardApplicable(uint256 i)
        external
        view
        returns (uint256);

    function lastUpdateTime() external view returns (uint256);

    function lastUpdateTimeForToken(address) external view returns (uint256);

    function lpToken() external view returns (address);

    function name() external view returns (string memory);

    function notifyRewardAmount(uint256 reward) external;

    function notifyTargetRewardAmount(address _rewardToken, uint256 reward)
        external;

    function owner() external view returns (address);

    function periodFinish() external view returns (uint256);

    function periodFinishForToken(address) external view returns (uint256);

    function pushAllRewards(address recipient) external;

    function removeRewardToken(address rt) external;

    function renounceOwnership() external;

    function rewardDistribution(address) external view returns (bool);

    function rewardPerToken(uint256 i) external view returns (uint256);

    function rewardPerToken() external view returns (uint256);

    function rewardPerToken(address rt) external view returns (uint256);

    function rewardPerTokenStored() external view returns (uint256);

    function rewardPerTokenStoredForToken(address)
        external
        view
        returns (uint256);

    function rewardRate() external view returns (uint256);

    function rewardRateForToken(address) external view returns (uint256);

    function rewardToken() external view returns (address);

    function rewardTokens(uint256) external view returns (address);

    function rewardTokensLength() external view returns (uint256);

    function rewards(address user) external view returns (uint256);

    function rewardsForToken(address, address) external view returns (uint256);

    function setRewardDistribution(
        address[] memory _newRewardDistribution,
        bool _flag
    ) external;

    function setStorage(address _store) external;

    function stake(uint256 amount) external;

    function stakedBalanceOf(address) external view returns (uint256);

    function store() external view returns (address);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferOwnership(address newOwner) external;

    function userRewardPerTokenPaid(address user)
        external
        view
        returns (uint256);

    function userRewardPerTokenPaidForToken(address, address)
        external
        view
        returns (uint256);

    function withdraw(uint256 amount) external;
}
