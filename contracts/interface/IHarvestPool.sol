// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IHarvestPool {
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function announceStrategyUpdate(address _strategy) external;

    function approve(address spender, uint256 amount) external returns (bool);

    function availableToInvestOut() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function canUpdateStrategy(address _strategy) external view returns (bool);

    function controller() external view returns (address);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);

    function deposit(uint256 amount) external;

    function depositFor(uint256 amount, address holder) external;

    function doHardWork() external;

    function finalizeStrategyUpdate() external;

    function finalizeUpgrade() external;

    function futureStrategy() external view returns (address);

    function getPricePerFullShare() external view returns (uint256);

    function governance() external view returns (address);

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    function initialize(
        address _underlying,
        uint256 _toInvestNumerator,
        uint256 _toInvestDenominator,
        uint256 _underlyingUnit,
        uint256 _implementationChangeDelay,
        uint256 _strategyChangeDelay
    ) external;

    function initialize(address _storage) external;

    function initializeVault(
        address _storage,
        address _underlying,
        uint256 _toInvestNumerator,
        uint256 _toInvestDenominator
    ) external;

    function name() external view returns (string memory);

    function nextImplementation() external view returns (address);

    function nextImplementationDelay() external view returns (uint256);

    function nextImplementationTimestamp() external view returns (uint256);

    function rebalance() external;

    function scheduleUpgrade(address impl) external;

    function setStorage(address _store) external;

    function setStrategy(address _strategy) external;

    function setVaultFractionToInvest(uint256 numerator, uint256 denominator)
        external;

    function shouldUpgrade() external view returns (bool, address);

    function strategy() external view returns (address);

    function strategyTimeLock() external view returns (uint256);

    function strategyUpdateTime() external view returns (uint256);

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

    function underlying() external view returns (address);

    function underlyingBalanceInVault() external view returns (uint256);

    function underlyingBalanceWithInvestment() external view returns (uint256);

    function underlyingBalanceWithInvestmentForHolder(address holder)
        external
        view
        returns (uint256);

    function underlyingUnit() external view returns (uint256);

    function vaultFractionToInvestDenominator() external view returns (uint256);

    function vaultFractionToInvestNumerator() external view returns (uint256);

    function withdraw(uint256 numberOfShares) external;

    function withdrawAll() external;
}
