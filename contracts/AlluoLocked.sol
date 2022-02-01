// // SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract AlluoLocked is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // ERC20 token locking to the contract.
    IERC20Upgradeable public lockingToken;
    // ERC20 token earned by locker as reward.
    IERC20Upgradeable public rewardToken;

    // Locking's reward amount produced per distribution time.
    uint256 public rewardPerDistribution;
    // Locking's start time.
    uint256 public startTime;

    // Locking's reward distribution time.
    uint256 public distributionTime;
    // Amount of currently locked tokens from all users.
    uint256 public totalLocked;
    // Amount of currently claimed rewards by the users.
    uint256 public totalDistributed;

    // Аuxiliary parameter (tpl) for locking's math
    uint256 public tokensPerLock;
    // Аuxiliary parameter for locking's math
    uint256 public rewardProduced;
    // Аuxiliary parameter for locking's math
    uint256 public allProduced;
    // Аuxiliary parameter for locking's math
    uint256 public producedTime;
    //
    uint256 public lockDuration = 86400 * 4;

    //erc20-like interface
    struct TokenInfo{
        string name;
        string symbol;
        uint8 decimals;
    }

    TokenInfo private token;

    // Locker contains info related to each locker.
    struct Locker {
        uint256 amount; // Tokens currently locked to the contract and vote power
        uint256 rewardAllowed; // Rewards allowed to be paid out
        uint256 rewardDebt; // Param is needed for correct calculation locker's share
        uint256 distributed; // Amount of distributed tokens
        uint256 unlockAmount; // Amount of tokens which is available to unlock
        uint256 unlockTime; // The time when tokens are available to withdraw
    }

    // Lockers info by token holders.
    mapping(address => Locker) public _lockers;

    /**
     * @dev Emitted in `initialize` when the locking was initialized
     */
    event LockingInitialized(address lockingToken, address rewardToken);

    /**
     * @dev Emitted in `updateUnlockClaimTime` when the unlock time to claim was updated
     */
    event UnlockClaimTimeUpdated(uint256 time, uint256 timestamp);

    /**
     * @dev Emitted in `setReward` when the new rewardPerDistribution was set
     */
    event RewardAmountUpdated(uint256 amount, uint256 produced);

    /**
     * @dev Emitted in `lock` when the user locked the tokens
     */
    event TokensLocked(uint256 amount, uint256 time, address indexed sender);

    /**
     * @dev Emitted in `transfer` when the user transfers the tokens
     */
    event TokensTransfered(address indexed sender, address indexed recipient, uint256 amount, uint256 time);

    /**
     * @dev Emitted in `claim` when the user claimed his reward tokens
     */
    event TokensClaimed(uint256 amount, uint256 time, address indexed sender);
    
    /**
     * @dev Emitted in `unlock` when the user unbinded his locked tokens
     */
    event TokensUnlocked(uint256 amount, uint256 time, address indexed sender);
    /**
     * @dev Emitted in `withdraw` when the user withdrew his locked tokens from the contract
     */
    event TokensWithdrawed(
        uint256 amount,
        uint256 time,
        address indexed sender
    );

    /**
     * @dev Contract constructor without parameters
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}


    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    /**
     * @dev Contract constructor 
     */
    function initialize(
        uint256 _rewardPerDistribution,
        uint256 _startTime,
        uint256 _distributionTime,
        address _rewardToken,
        address _lockingToken
    ) public initializer{
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        //token = TokenInfo("Vote Locked Alluo Token", "vlAlluo", 18) {

        token = TokenInfo({
            name: "Vote Locked Alluo Token",
            symbol: "vlAlluo",
            decimals: 18
        });

        rewardPerDistribution = _rewardPerDistribution;
        startTime = _startTime;
        distributionTime = _distributionTime;
        producedTime = _startTime;

        rewardToken = IERC20Upgradeable(_rewardToken);
        lockingToken = IERC20Upgradeable(_lockingToken);
        emit LockingInitialized(_lockingToken, _rewardToken);
    }

    function decimals() public view returns (uint8) {
        return token.decimals;
    }
    function name() public view returns (string memory) {
        return token.name;
    }
    function symbol() public view returns (string memory) {
        return token.symbol;
    }

    /**
     * @dev Calculates the necessary parameters for locking
     * @return Totally produced rewards
     */
    function produced() private view returns (uint256) {
        return
            allProduced +
            (rewardPerDistribution * (block.timestamp - producedTime)) /
            distributionTime;
    }

    /**
     * @dev Updates the produced rewards parameter for locking
     */
    function update() public whenNotPaused {
        uint256 rewardProducedAtNow = produced();
        if (rewardProducedAtNow > rewardProduced) {
            uint256 producedNew = rewardProducedAtNow - rewardProduced;
            if (totalLocked > 0) {
                tokensPerLock =
                    tokensPerLock +
                    (producedNew * 1e20) /
                    totalLocked;
            }
            rewardProduced = rewardProduced + producedNew;
        }
    }

    /**
     * @dev Locks specified amount to the contract
     * @param _amount An amount to lock
     */
    function lock(uint256 _amount) public {
        require(
            block.timestamp > startTime,
            "Locking: locking time has not come yet"
        );

        Locker storage locker = _lockers[msg.sender];

        // Transfer specified amount of locking tokens to the contract
        IERC20Upgradeable(lockingToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        if (totalLocked > 0) {
            update();
        }
        locker.rewardDebt =
            locker.rewardDebt +
            ((_amount * tokensPerLock) / 1e20);

        totalLocked = totalLocked + _amount;
        locker.amount = locker.amount + _amount;
        if(locker.unlockTime == 0){
            locker.unlockTime = type(uint256).max;
        }

        emit TokensLocked(_amount, block.timestamp, msg.sender);
    }

    /**
    * @dev Transfers specified amount of tokens 
    * @param _to recipient of tokens
    * @param _amount An amount to unbid
    */
    function transfer(address _to, uint256 _amount) public nonReentrant {
        Locker storage sender = _lockers[msg.sender];

        require(
            sender.amount >= _amount,
            "Locking: Not enough tokens to transfer"
        );
        Locker storage recipient = _lockers[_to];

        update();

        sender.rewardAllowed =
            sender.rewardAllowed +
            ((_amount * tokensPerLock) / 1e20);

        recipient.rewardDebt =
            recipient.rewardDebt +
            ((_amount * tokensPerLock) / 1e20);

        sender.amount -= _amount;
        recipient.amount += _amount;

        if(recipient.unlockTime == 0){
            recipient.unlockTime = type(uint256).max;
        }

        emit TokensTransfered(msg.sender, _to, _amount, block.timestamp);
    }

    /**
    * @dev Unbinds specified amount of tokens
    * @param _amount An amount to unbid
    */
    function unlock(uint256 _amount) public nonReentrant {
        Locker storage locker = _lockers[msg.sender];

        require(
            locker.amount >= _amount,
            "Locking: Not enough tokens to unlock"
        );

        update();

        locker.rewardAllowed =
            locker.rewardAllowed +
            ((_amount * tokensPerLock) / 1e20);

        locker.amount -= _amount;
        totalLocked -= _amount;

        locker.unlockAmount += _amount;
        //revering time to last thursday and adding week + lockDuration
        locker.unlockTime = (block.timestamp / lockDuration * lockDuration) + 86400 * 7 + lockDuration;

        emit TokensUnlocked(_amount, block.timestamp, msg.sender);
    }

    /**
     * @dev Unbinds all amount of locked tokens
     */
    function unlockAll() public nonReentrant {
        Locker storage locker = _lockers[msg.sender];

        require(
            locker.amount >= 0,
            "Locking: Not enough tokens to unlock"
        );
        uint256 amount = locker.amount;

        update();

        locker.rewardAllowed =
            locker.rewardAllowed +
            ((amount * tokensPerLock) / 1e20);
        locker.amount = 0;
        totalLocked -= amount;

        locker.unlockAmount += amount;
        //revering time to last thursday and adding week + lockDuration
        locker.unlockTime = (block.timestamp / (86400 * 7) * (86400 * 7)) + 86400 * 7 + lockDuration;

        emit TokensUnlocked(amount, block.timestamp, msg.sender);
    }

    /**
     * @dev Unlocks unbinded tokens and transfers them to locker's address
     */
    function withdraw() public nonReentrant {
        Locker storage locker = _lockers[msg.sender];

        require(
            locker.unlockAmount > 0,
            "Locking: Not enough tokens to unlock"
        );

        require(
            block.timestamp >= locker.unlockTime,
            "Locking: Unlocked tokens are not available yet."
        );

        uint256 amount = locker.unlockAmount;
        locker.unlockAmount = 0;
        locker.unlockTime = type(uint256).max;
        IERC20Upgradeable(lockingToken).safeTransfer(msg.sender, amount);
        emit TokensWithdrawed(amount, block.timestamp, msg.sender);
    }

    /**
     * @dev Сlaims available rewards
     * @return Boolean result
     */
    function claim() public nonReentrant returns (bool) {

        if (totalLocked > 0) {
            update();
        }

        uint256 reward = calcReward(msg.sender, tokensPerLock);
        require(reward > 0, "Locking: Nothing to claim");

        Locker storage locker = _lockers[msg.sender];

        locker.distributed = locker.distributed + reward;
        totalDistributed = totalDistributed + reward;

        IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, reward);
        emit TokensClaimed(reward, block.timestamp, msg.sender);
        return true;
    }

    /**
     * @dev Claims all available rewards and unlocks the tokens
     */
    function claimAndUnlock() public {
        unlockAll();

        uint256 reward = getClaim(msg.sender);
        if (reward > 0) {
            claim();
        }
    }

    /**
     * @dev Сalculates available reward
     * @param _locker Address of the locker
     * @param _tpl Tokens per lock parameter
     */
    function calcReward(address _locker, uint256 _tpl)
        private
        view
        returns (uint256 reward)
    {
        Locker storage locker = _lockers[_locker];

        reward =
            ((locker.amount * _tpl) / 1e20) +
            locker.rewardAllowed -
            locker.distributed -
            locker.rewardDebt;

        return reward;
    }

  /**
     * @dev Returns locker's available rewards
     * @param _locker Address of the locker
     * @return reward Available reward to claim
     */
    function getClaim(address _locker) public view returns (uint256 reward) {
        uint256 _tpl = tokensPerLock;
        if (totalLocked > 0) {
            uint256 rewardProducedAtNow = produced();
            if (rewardProducedAtNow > rewardProduced) {
                uint256 producedNew = rewardProducedAtNow - rewardProduced;
                _tpl = _tpl + ((producedNew * 1e20) / totalLocked);
            }
        }
        reward = calcReward(_locker, _tpl);

        return reward;
    }

    /**
     * @dev Returns information about the specified locker
     * @param _address Locker's address
     * @return amount of vote/locked tokens
     */
    function balanceOf(address _address) external view  returns(uint256 amount) {
        return _lockers[_address].amount;
    }

    /**
     * @dev Returns information about the specified locker
     * @param _address Locker's address
     * @return locked_ Locked amount of tokens
     * @return claim_  Reward amount available to be claimed
     * @return unlockAmount_ Unlocked amount of tokens
     * @return unlockTime_ Timestamp when tokens were unlocked
     */
    function getInfoByAddress(address _address)
        external
        view
        returns (
            uint256 locked_,
            uint256 claim_,
            uint256 unlockAmount_,
            uint256 unlockTime_
        )
    {
        Locker storage locker = _lockers[_address];
        locked_ = locker.amount;
        unlockAmount_ = locker.unlockAmount;
        unlockTime_ = locker.unlockTime;
        claim_ = getClaim(_address);

        return (locked_, claim_, unlockAmount_, unlockTime_);
    }

    /* ========== ADMIN CONFIGURATION ========== */

    ///@dev Pauses the locking
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    ///@dev Unpauses the locking
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Adds reward tokens to the contract
     * @param _amount Specifies the amount of tokens to be transferred to the contract
     */
    function addReward(uint256 _amount) external {
        IERC20Upgradeable(rewardToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
    }

    /**
     * @dev Sets amount of reward during `distributionTime`
     * @param _amount Sets total reward amount per `distributionTime`
     */
    function setReward(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        allProduced = produced();
        producedTime = block.timestamp;
        rewardPerDistribution = _amount;
        emit RewardAmountUpdated(_amount, allProduced);
    }

    /**
     * @dev Removes any token from the contract by its address
     * @param _address Token's address
     * @param _amount An amount to be removed from the contract
     */
    function removeTokenByAddress(address _address, uint256 _amount)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_address != address(0), "Invalid token address");
        IERC20Upgradeable(_address).safeTransfer(msg.sender, _amount);
    }

    /**
     * @dev Allows to update the 'produced time' parameter
     * @param _producedTime Date in unix timestamp format
     */
    function updateProducedTime(uint256 _producedTime)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_producedTime >= 0, "The value must be possitive");
        producedTime = _producedTime;
    }

    /**
     * @dev Allows to update 'tokens per lock' parameter
     * @param _tpl Specifeies the new tokens per lock value
     */
    function updateTpl(uint256 _tpl) external onlyRole(ADMIN_ROLE) {
        require(_tpl >= 0, "TPL must be possitive");
        tokensPerLock = _tpl;
    }

    /**
     * @dev Allows to update the value of all produced reward parameter
     * @param _allProduced Specifeies the new value of rewards totally produced
     */
    function updateAllProduced(uint256 _allProduced)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_allProduced >= 0, "Amount must be possitive");
        allProduced = _allProduced;
    }

    /**
     * @dev Allows to update the value of produced reward
     * @param _rewardProduced Specifeies the new value of rewards produced
     */
    function updateRewardProduced(uint256 _rewardProduced)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_rewardProduced >= 0, "Amount must be possitive");
        rewardProduced = _rewardProduced;
    }

    /**
     * @dev Allows to update the daily reward parameter
     * @param _rewardPerDistribution Specifeies the new daily reward value
     */
    function updateRewardPerDistribution(uint256 _rewardPerDistribution)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_rewardPerDistribution >= 0, "Amount must be possitive");
        rewardPerDistribution = _rewardPerDistribution;
    }

    /**
     * @dev Allows to update the value of locked tokens
     * @param _totalLocked Specifeies the new value of totally locked tokens
     */
    function updateTotalLocked(uint256 _totalLocked)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_totalLocked >= 0, "Amount must be possitive");
        totalLocked = _totalLocked;
    }

    /**
     * @dev Allows to update the value of distributed rewards
     * @param _totalDistributed Specifeies the new value of totally distributed rewards
     */
    function updateTotalDistributed(uint256 _totalDistributed)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_totalDistributed >= 0, "Amount must be possitive");
        totalDistributed = _totalDistributed;
    }

    /**
     * @dev Updates user's information
     * @param _user Locker's address
     * @param _amount Amount of locked tokens
     * @param _rewardAllowed Amount of reward which is allowed to be paid out
     * @param _rewardDebt Amount of reward debt
     * @param _distributed Amount of distributed rewards
     * @param _unlockAmount Amount of unlocked tokens
     * @param _unlockTime Last timestamp when locker unlocked his tokens
     */
    function updateLockerInfo(
        address _user,
        uint256 _amount,
        uint256 _rewardAllowed,
        uint256 _rewardDebt,
        uint256 _distributed,
        uint256 _unlockAmount,
        uint256 _unlockTime
    ) external onlyRole(ADMIN_ROLE) {
        Locker storage locker = _lockers[_user];

        locker.amount = _amount;
        locker.rewardAllowed = _rewardAllowed;
        locker.rewardDebt = _rewardDebt;
        locker.distributed = _distributed;
        locker.unlockAmount = _unlockAmount;
        locker.unlockTime = _unlockTime;
    }

}