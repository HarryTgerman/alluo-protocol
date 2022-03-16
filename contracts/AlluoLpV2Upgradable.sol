// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./AlluoERC20Upgradable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {Exchange} from "alluo-exchange/contracts/Exchange.sol";

contract AlluoLpV2UpgradableMintable is
    Initializable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    AlluoERC20Upgradable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Debt factor: variable which grow after any action from user
    // based on current interest rate and time from last update call
    // this is a large number for a more accurate calculation
    uint256 public DF;

    // time of last DF update
    uint256 public lastDFUpdate;

    // time limit for using update
    uint256 public updateTimeLimit;

    // DF of user from last user action on contract
    mapping(address => uint256) public userDF;

    // list of tokens from which deposit available
    EnumerableSetUpgradeable.AddressSet private supportedTokens;

    // constant for percent calculation
    uint256 public DENOMINATOR;

    // admin and reserves address
    address public wallet;

    // current interest rate
    uint8 public interest;

    //flag for upgrades availability
    bool public upgradeStatus;

    //token deposit to be converted into
    address targetToken;

    //onchain exchange
    address payable exchangeAddress;

    //onchain exchange
    uint256 slippageBPS;

    // user intrest accured
    mapping(address => uint256) public userIntrest;

    event BurnedForWithdraw(address indexed user, uint256 amount);
    event Deposited(address indexed user, address token, uint256 amount);
    event InterestChanged(uint8 oldInterest, uint8 newInterest);
    event NewWalletSet(address oldWallet, address newWallet);
    event ApyClaimed(address indexed user, uint256 apyAmount);
    event UpdateTimeLimitSet(uint256 oldValue, uint256 newValue);
    event DepositTokenStatusChanged(address token, bool status);
    event TargetTokenChanged(address oldTargetToken, address newTargetToken);
    event ExchangeAddressChanged(
        address oldExchangeAddress,
        address newExchangeAddress
    );
    event SlippageBPSChanged(uint256 oldSlippageBPS, uint256 newSlippageBPS);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(
        address _multiSigWallet,
        address[] memory _supportedTokens,
        address _targetToken,
        address payable _exchangeAddress,
        uint256 _slippageBPS
    ) public initializer {
        __ERC20_init("ALLUO LP", "LPALL");
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        require(
            _multiSigWallet.isContract(),
            "AlluoLpUpgradable: not contract"
        );

        _grantRole(DEFAULT_ADMIN_ROLE, _multiSigWallet);
        _grantRole(UPGRADER_ROLE, _multiSigWallet);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);

        DF = 10**20;
        updateTimeLimit = 3600;
        DENOMINATOR = 10**20;
        interest = 8;

        targetToken = _targetToken;
        exchangeAddress = _exchangeAddress;
        slippageBPS = _slippageBPS;
        wallet = _multiSigWallet;

        for (uint256 i = 0; i < _supportedTokens.length; i++) {
            supportedTokens.add(_supportedTokens[i]);
        }

        lastDFUpdate = block.timestamp;
        update();

        emit InterestChanged(0, interest);
        emit NewWalletSet(address(0), wallet);
    }

    function update() public whenNotPaused {
        uint256 timeFromLastUpdate = block.timestamp - lastDFUpdate;
        if (timeFromLastUpdate >= updateTimeLimit) {
            DF =
                ((DF *
                    (((interest * DENOMINATOR * timeFromLastUpdate) /
                        31536000) + (100 * DENOMINATOR))) / DENOMINATOR) /
                100;
            lastDFUpdate = block.timestamp;
        }
    }

    function _intrestAccured(address _address) internal whenNotPaused {}

    function withdraw(uint256 _amount, address _desiredToken)
        external
        whenNotPaused
        nonReentrant
    {
        require(
            supportedTokens.contains(_desiredToken),
            "AlluoLpV2UpgradableMintable#withdraw:TOKEN_NOT_SUPPORTED"
        );
        uint256 userBalance = balanceOf(msg.sender);
        require(
            userBalance != 0 && userBalance >= _amount,
            "AlluoLpV2UpgradableMintable#withdraw:BALANCE_TO_LOW"
        );
        update();

        uint256 intrestAmount = (((DF * _amount) / userDF[msg.sender]) -
            _amount);

        uint256 realAmount = _amount + intrestAmount;

        uint256 targetTokenDecimalsMult = 10 **
            (AlluoERC20Upgradable(targetToken).decimals() - 18);

        uint256 targetTokenAmount = realAmount * targetTokenDecimalsMult;

        if (_desiredToken != targetToken) {
            uint256 desiredTokenDecimalsMult = 10 **
                (AlluoERC20Upgradable(_desiredToken).decimals() -
                    AlluoERC20Upgradable(targetToken).decimals());

            IERC20Upgradeable(targetToken).safeTransferFrom(
                wallet,
                address(this),
                targetTokenAmount
            );

            // subtract slippage and format to targetToken decimals
            uint256 minOutput = (targetTokenAmount -
                ((targetTokenAmount * slippageBPS) / 10000)) *
                desiredTokenDecimalsMult;

            uint256 outputAmount = Exchange(exchangeAddress).exchange(
                targetToken,
                _desiredToken,
                targetTokenAmount,
                minOutput
            );

            IERC20Upgradeable(_desiredToken).safeTransfer(
                msg.sender,
                outputAmount
            );
        } else {
            IERC20Upgradeable(targetToken).safeTransferFrom(
                wallet,
                msg.sender,
                targetTokenAmount
            );
        }

        _burn(msg.sender, _amount);

        emit BurnedForWithdraw(msg.sender, realAmount);
    }

    function deposit(address _token, uint256 _amount)
        external
        whenNotPaused
        nonReentrant
    {
        require(
            supportedTokens.contains(_token),
            "AlluoLpV2UpgradableMintable#deposit:TOKEN_NOT_SUPPORTED"
        );

        if (_token != targetToken) {
            uint256 targetTokenDecimalsMult = 10 **
                (AlluoERC20Upgradable(targetToken).decimals() -
                    AlluoERC20Upgradable(_token).decimals());
            // subtract slippage and format to targetToken decimals
            uint256 minOutput = (_amount - ((_amount * slippageBPS) / 10000)) *
                targetTokenDecimalsMult;

            uint256 outputAmount = Exchange(exchangeAddress).exchange(
                _token,
                targetToken,
                _amount,
                minOutput
            );
            IERC20Upgradeable(targetToken).safeTransfer(wallet, outputAmount);
        } else {
            IERC20Upgradeable(targetToken).safeTransferFrom(
                msg.sender,
                wallet,
                _amount
            );
        }

        uint256 amountIn18 = _amount *
            10**(18 - AlluoERC20Upgradable(_token).decimals());

        uint256 userBalance = balanceOf(msg.sender);
        update();

        if (userBalance > 0) {
            uint256 intrestAmount = (((DF * userBalance) / userDF[msg.sender]) -
                userBalance);
            _mint(msg.sender, amountIn18 + intrestAmount);
            userDF[msg.sender] = DF;
            emit Deposited(msg.sender, _token, amountIn18 + intrestAmount);
        } else {
            _mint(msg.sender, amountIn18);
            userDF[msg.sender] = DF;
            emit Deposited(msg.sender, _token, amountIn18);
        }
    }

    function mint(address _user, uint256 _amount)
        external
        whenNotPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _mint(_user, _amount);
    }

    function changeTokenStatus(address _token, bool _status)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_status) {
            supportedTokens.add(_token);
        } else {
            supportedTokens.remove(_token);
        }
        emit DepositTokenStatusChanged(_token, _status);
    }

    function setInterest(uint8 _newInterest)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        update();
        uint8 oldValue = interest;
        interest = _newInterest;

        emit InterestChanged(oldValue, _newInterest);
    }

    function setUpdateTimeLimit(uint256 _newLimit)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 oldValue = updateTimeLimit;
        updateTimeLimit = _newLimit;

        emit UpdateTimeLimitSet(oldValue, _newLimit);
    }

    function setWallet(address newWallet)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newWallet.isContract(), "UrgentAlluoLp: not contract");

        address oldValue = wallet;
        wallet = newWallet;

        emit NewWalletSet(oldValue, newWallet);
    }

    function setTargetToken(address _targetToken)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        address oldTargetToken = targetToken;
        targetToken = _targetToken;
        emit TargetTokenChanged(oldTargetToken, _targetToken);
    }

    function setExchangeAddress(address payable _exchangeAddress)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        address oldExchangeAddress = exchangeAddress;
        exchangeAddress = _exchangeAddress;
        emit ExchangeAddressChanged(oldExchangeAddress, _exchangeAddress);
    }

    function setSlippage(uint256 _slippageBPS)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 oldSlippageBPS = slippageBPS;
        slippageBPS = _slippageBPS;
        emit SlippageBPSChanged(oldSlippageBPS, _slippageBPS);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function grantRole(bytes32 role, address account)
        public
        override
        onlyRole(getRoleAdmin(role))
    {
        if (role == DEFAULT_ADMIN_ROLE) {
            require(account.isContract(), "UrgentAlluoLp: not contract");
        }
        _grantRole(role, account);
    }

    function changeUpgradeStatus(bool _status)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        upgradeStatus = _status;
    }

    function getBalance(address _address) public view returns (uint256) {
        if (userDF[_address] != 0) {
            uint256 timeFromLastUpdate = block.timestamp - lastDFUpdate;
            uint256 localDF;
            if (timeFromLastUpdate >= updateTimeLimit) {
                localDF =
                    ((DF *
                        (((interest * DENOMINATOR * timeFromLastUpdate) /
                            31536000) + (100 * DENOMINATOR))) / DENOMINATOR) /
                    100;
            } else {
                localDF = DF;
            }
            return ((localDF * balanceOf(_address)) / userDF[_address]);
        } else {
            return 0;
        }
    }

    function getListSupportedTokens() public view returns (address[] memory) {
        return supportedTokens.values();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // _claim(from);
        // claim(to);
        super._beforeTokenTransfer(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        view
        override
        onlyRole(UPGRADER_ROLE)
    {
        require(upgradeStatus, "Upgrade not allowed");
    }
}