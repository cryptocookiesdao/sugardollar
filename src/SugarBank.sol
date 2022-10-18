// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Owned} from "solmate/auth/Owned.sol";
import {IUniswapV2Router02} from "v2-periphery/interfaces/IUniswapV2Router02.sol";

import {IERC20, IERC20Burneable} from "./interfaces/IERC20Burneable.sol";
import {IGame} from "./interfaces/IGame.sol";
import {IBankVault} from "./interfaces/IBankVault.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {ICollateralPolicy} from "./interfaces/ICollateralPolicy.sol";

//                                      ___---___
//                                ___---___---___---___
//                          ___---___---    *    ---___---___
//                    ___---___---    o/ 0_/  @  o ^   ---___---___
//              ___---___--- @  i_e J-U /|  -+D O|-| (o) /   ---___---___
//        ___---___---    __/|  //\  /|  |\  /\  |\|  |_  __--oj   ---___---___
//   __---___---_________________________________________________________---___---__
//   ===============================================================================
//    ||||                          SUGAR BANK V1.0.0                          ||||
//    |---------------------------------------------------------------------------|
//    |___-----___-----___-----___-----___-----___-----___-----___-----___-----___|
//    / _ \===/ _ \   / _ \===/ _ \   / _ \===/ _ \   / _ \===/ _ \   / _ \===/ _ \
//   ( (.\ oOo /.) ) ( (.\ oOo /.) ) ( (.\ oOo /.) ) ( (.\ oOo /.) ) ( (.\ oOo /.) )
//    \__/=====\__/   \__/=====\__/   \__/=====\__/   \__/=====\__/   \__/=====\__/
//       |||||||         |||||||         |||||||         |||||||         |||||||
//       |||||||         |||||||         |||||||         |||||||         |||||||
//       |||||||         |||||||         |||||||         |||||||         |||||||
//       |||||||         |||||||         |||||||         |||||||         |||||||
//       |||||||         |||||||         |||||||         |||||||         |||||||
//       |||||||         |||||||         |||||||         |||||||         |||||||
//       |||||||         |||||||         |||||||         |||||||         |||||||
//       |||||||         |||||||         |||||||         |||||||         |||||||
//       (oOoOo)         (oOoOo)         (oOoOo)         (oOoOo)         (oOoOo)
//       J%%%%%L         J%%%%%L         J%%%%%L         J%%%%%L         J%%%%%L
//      ZZZZZZZZZ       ZZZZZZZZZ       ZZZZZZZZZ       ZZZZZZZZZ       ZZZZZZZZZ
//     ===========================================================================
//   __|_____________________ https://cryptocookiesdao.com/ _____________________|__
//   _|___________________________________________________________________________|_
//   |_____________________________________________________________________________|
//   _______________________________________________________________________________
//
//                                  SUGAR BANK V1.0.0

/// @title SugarBank
/// @dev This contract manages the minting and redeeming of sUSD tokens.
contract SugarBank is Owned(msg.sender) {
    IUniswapV2Router02 public immutable ROUTER;

    // The sUSD token.
    IERC20Burneable public immutable SUSD;
    // The CKIE token.
    IERC20Burneable public immutable CKIE;
    // The DAI token.
    IERC20 public immutable DAI;
    address immutable WMATIC;

    address immutable DEV;

    // THe GAME will allow us to mint CKIE tokens. Used on redeem
    IGame public immutable GAME;

    // The treaseury is where all the DAI tokens that back SUSD are stored.
    IBankVault public immutable TREASURY;

    // Oracle for DAI, SUSD and CKIE prices in USD.
    IOracle public oracle;

    // Collateral policy to know the percentage of collateral that is required for minting.
    ICollateralPolicy public collateralPolicy;

    /// @notice lastUpdate of the interval (used for mint&burn limits)
    uint256 public lastUpdate;
    /// @notice _maxBurn amount of SUSD that can be redeem in a UPDATE_INTERVAL seconds interval.
    uint256 private _maxBurn;
    /// @notice _maxMint amount of SUSD that can be mint in a UPDATE_INTERVAL seconds interval.
    uint256 private _maxMint;
    /// @notice path to zap DAI to CKIE
    address[] private _pathDaiCkie;

    /// @notice mint fee, 30 = 0.3%,
    uint256 public mintFee = 30_0000;
    // redeem fee
    uint256 public burnFee = 30_0000;

    // Seconds between updates of the mint&burn limits.
    uint256 public constant UPDATE_INTERVAL = 600;

    // percentage of max mint&burn limits for each interval, 1e7 = 10%
    uint256 public constant MAX_PERCENTAGE = 1e7;

    uint256 public constant BASE = 1e8;

    mapping(address => uint256) public waitBlock;
    mapping(address => uint256) public pending;

    /**
     * EMERGENCY MIGRATION (with timelock) *
     */
    struct Migration {
        address targetContract;
        address newOwner;
        uint256 execTimestamp;
    }

    mapping(address => Migration) public pendingMigration;

    error errBurnFeeTooHigh();
    error errInvalidMigration();
    error errMigrationTooEarly();
    error errNoAddressZero();
    error errNothingToClaim();
    error errWaitMoreBlocks();
    error errMaxMintReach();
    error errMaxBurnReach();
    error errSlippageCheck();
    error errPriceError();
    error errOwnershipTransfer(bytes);

    /**
     * EVENTS
     */
    event UpdateLimits(uint256 _maxMint, uint256 _maxBurn);
    event TimelockMigration(Migration pendingMigration);
    event TimelockMigrate(Migration pendingMigration);
    event CollateralPolicyUpdate(address collateralPolicy);
    event OracleUpdate(address oracle);
    event FeeUpdate(uint256 _mintFee, uint256 _burnFee);
    event Redeem(address account, uint256 susdBurnAmount, uint256 daiAmount, uint256 mintCkieAmount);
    event Claim(address account, uint256 susdAmount);

    constructor(
        address _router,
        address _susd,
        address _ckie,
        address _dai,
        address _game,
        address _treasury,
        address _oracle,
        address _collateralPolicy
    ) {
        DEV = msg.sender;

        ROUTER = IUniswapV2Router02(_router);
        WMATIC = ROUTER.WETH();

        // The sUSD token.
        SUSD = IERC20Burneable(_susd);
        // The CKIE token.
        CKIE = IERC20Burneable(_ckie);
        // The DAI token.
        DAI = IERC20(_dai);

        // The GAME will allow us to mint CKIE tokens. Used on redeem action.
        GAME = IGame(_game);

        TREASURY = IBankVault(_treasury);
        oracle = IOracle(_oracle);

        // approve DAI for zapping
        DAI.approve(_router, type(uint256).max);

        collateralPolicy = ICollateralPolicy(_collateralPolicy);

        _maxBurn = 500 ether;
        _maxMint = 500 ether;
        _update();

        address[] memory _path = new address[](3);
        _path[0] = address(DAI);
        _path[1] = address(SUSD);
        _path[2] = address(CKIE);
        _pathDaiCkie = _path;
    }

    // owner functions

    /// @notice Update the collateral policy
    function setCollateralPolicy(address _collateralPolicy) external onlyOwner {
        if (_collateralPolicy == address(0)) revert errNoAddressZero();
        collateralPolicy = ICollateralPolicy(_collateralPolicy);
        emit CollateralPolicyUpdate(_collateralPolicy);
    }

    /// @notice Update the current oracle
    function setOracle(address _oracle) external onlyOwner {
        if (_oracle == address(0)) revert errNoAddressZero();
        oracle = IOracle(_oracle);
        emit OracleUpdate(_oracle);
    }

    /// @notice Update the mint&burn fees.
    function updateBurnMintFees(uint256 burnFee_, uint256 mintFee_) external onlyOwner {
        if (burnFee_ > 5_00_0000 || mintFee_ > 5_00_0000) revert errBurnFeeTooHigh();
        mintFee = mintFee_;
        burnFee = burnFee_;
        emit FeeUpdate(mintFee_, burnFee_);
    }

    /// @notice Prepare a migration, this is use to transfer ownership of a contract that is own by the bank
    ///         This is useful for the migration of the contracts to a new sugarbank version
    function addMigration(address _contract, address _newOwner) external onlyOwner {
        pendingMigration[_contract] =
            Migration({targetContract: _contract, newOwner: _newOwner, execTimestamp: block.timestamp + 7 days});

        emit TimelockMigration(pendingMigration[_contract]);
    }

    function execMigration(address _contract, bool isSolmate) external onlyOwner {
        Migration memory _pendingMigration = pendingMigration[_contract];
        if (_pendingMigration.targetContract == address(0)) revert errInvalidMigration();
        if (_pendingMigration.execTimestamp > block.timestamp) revert errMigrationTooEarly();

        emit TimelockMigrate(_pendingMigration);
        delete pendingMigration[_contract];
        bool success;
        bytes memory response;
        if (isSolmate) {
            (success, response) = _pendingMigration.targetContract.call(abi.encodeWithSignature("setOwner(address)", _pendingMigration.newOwner));
        } else {
            (success, response) = _pendingMigration.targetContract.call(abi.encodeWithSignature("transferOwnership(address)", _pendingMigration.newOwner));
        }
        if (!success) {
            revert errOwnershipTransfer(response); 
        }
    }

    // user functions

    function mintZap(uint256 _amountDAI, uint256 _minAmountOut) external {
        // get the current target collateral ratio
        uint256 _tcr = collateralPolicy.updateAndGet();

        uint256 _amountDAItoCkie = (_amountDAI * (BASE - _tcr)) / BASE;

        if (_amountDAItoCkie == 0) {
            mint(_amountDAI, 0, _minAmountOut);
            return;
        }

        /// @dev by definition DAI will always work or revert, thats thy i dont use a SafeTransferLib.
        /// @dev please see https://github.com/makerdao/dss/blob/master/src/dai.sol#L89
        DAI.transferFrom(msg.sender, address(this), _amountDAItoCkie);

        uint256[] memory amounts =
            ROUTER.swapExactTokensForTokens(_amountDAItoCkie, 0, _pathDaiCkie, msg.sender, block.timestamp + 60);

        mint(_amountDAI - _amountDAItoCkie, amounts[2], _minAmountOut);
    }

    // this will mint new SUSD
    function mint(uint256 _amountDAI, uint256 _amountCOOKIE, uint256 _minAmountOut) public {
        _update();
        // cache mint limits
        uint256 maxMint_ = _maxMint;
        if (maxMint_ == 0) revert errMaxMintReach();
        // get the current target collateral ratio
        uint256 _tcr = collateralPolicy.updateAndGet();
        // get de DAI price in USD (base 8)
        uint256 daiPrice = oracle.daiPrice();

        uint256 amountToMint;

        if (_tcr == BASE) {
            // TCR is 100%, so it only use DAI to mint SUSD

            // Calculate the amount of SUSD to mint, if it's greater than the
            // _maxMint, it will be the _maxMint.

            // daiPrice is in base 1e8 thats why * 1e8
            amountToMint = (_amountDAI * daiPrice) / BASE;

            // Amount of DAI to back the new SUSD
            uint256 daiToTransfer = _amountDAI;

            if (amountToMint > maxMint_) {
                amountToMint = maxMint_;
                daiToTransfer = (amountToMint * BASE) / daiPrice;
            }

            if (daiToTransfer == 0) revert errPriceError();

            /// @dev by definition DAI will always work or revert, thats thy i dont use a SafeTransferLib.
            /// @dev please see https://github.com/makerdao/dss/blob/master/src/dai.sol#L89
            DAI.transferFrom(msg.sender, address(TREASURY), daiToTransfer);
        } else {
            uint256 cookieUSDPrice = oracle.cookiePrice();
            amountToMint = (_amountDAI * daiPrice) / _tcr;
            uint256 targetAmount2 = (_amountCOOKIE * cookieUSDPrice) / (BASE - _tcr);

            amountToMint = (amountToMint < targetAmount2) ? amountToMint : targetAmount2;

            if (amountToMint > maxMint_) {
                amountToMint = maxMint_;
            }

            _amountCOOKIE = (amountToMint * (BASE - _tcr)) / cookieUSDPrice;
            _amountDAI = (amountToMint * _tcr) / (daiPrice);

            if (_amountDAI == 0) revert errPriceError();
            /// @dev by definition DAI will always work or revert, thats thy i dont use a SafeTransferLib.
            /// @dev please see https://github.com/makerdao/dss/blob/master/src/dai.sol#L89
            DAI.transferFrom(msg.sender, address(TREASURY), _amountDAI);

            if (_amountCOOKIE > 0) {
                CKIE.burnFrom(msg.sender, _amountCOOKIE);
            }
        }

        if (amountToMint > 0) {
            unchecked {
                if ((_minAmountOut * (BASE - mintFee)) / BASE > amountToMint) revert errSlippageCheck();

                pending[msg.sender] += amountToMint;
                waitBlock[msg.sender] = block.number + 2;

                // Burn & Mint limits will be updated
                _maxMint -= amountToMint;
            }
        }

        emit UpdateLimits(_maxMint, _maxBurn);
    }

    function claim() external {
        uint256 _pending = pending[msg.sender];
        if (pending[msg.sender] == 0) revert errNothingToClaim();
        if (waitBlock[msg.sender] > block.number) revert errWaitMoreBlocks();

        uint256 _out = (_pending * (BASE - mintFee)) / BASE;
        delete pending[msg.sender];
        delete waitBlock[msg.sender];
        SUSD.mint(msg.sender, _out);
        // fee to mantein the protocol
        SUSD.mint(DEV, _pending - _out);

        emit Claim(msg.sender, _pending - _out);
    }

    ///@notice This will burn SUSD and give DAI and cookie to te user
    function redeem(uint256 amount) external {
        if (amount == 0) revert errPriceError();
        _update();
        // cache max burn limits
        uint256 maxBurn_ = _maxBurn;
        if (maxBurn_ == 0) revert errMaxBurnReach();

        if (amount > maxBurn_) {
            amount = maxBurn_;
        }

        unchecked {
            _maxBurn -= amount;
            // maxMint += amount;
        }

        // Effective Collateral Ratio en % con base 1e8 = 100%, need get it before burn
        uint256 _ecr = getECR();

        uint256 totalBurnAmount = amount;

        unchecked {
            amount = (totalBurnAmount * (BASE - burnFee)) / BASE;
            // fee to mantein the protocol
            SUSD.transferFrom(msg.sender, address(DEV), totalBurnAmount - amount);
        }

        SUSD.burnFrom(msg.sender, amount);

        // oracle get DAI price in USD (chainlink)
        uint256 daiPrice = oracle.daiPrice();

        // total DAI
        uint256 totalDAI = (amount * _ecr) / BASE;

        if (totalDAI != 0) {
            TREASURY.transferDAI(msg.sender, totalDAI);
        }
        if (_ecr < BASE) {
            uint256 cookieUSDPrice = oracle.cookiePrice();
            // min cookie USD price = 10000
            if (cookieUSDPrice < 10000) {
                cookieUSDPrice = 10000;
            }

            uint256 _pendingAmount = amount - ((daiPrice * totalDAI) / BASE);
            _pendingAmount = (_pendingAmount * BASE) / cookieUSDPrice;
            GAME.sugarBankMint(msg.sender, _pendingAmount);
            emit Redeem(msg.sender, amount, totalDAI, _pendingAmount);
        } else {
            emit Redeem(msg.sender, amount, totalDAI, 0);
        }

        emit UpdateLimits(_maxMint, _maxBurn);
    }

    /// @notice Anyone cant trigger the update of the burn and mint limits
    function update() external {
        _update();
    }

    /// @notice This function will update the max amount to burn or mint in an interval,
    /// the key of this mechanism is to give some time space to recover on a worst case scenario
    function _update() internal {
        if (block.timestamp - lastUpdate > UPDATE_INTERVAL) {
            lastUpdate = block.timestamp;
            uint256 _max = (SUSD.totalSupply() * MAX_PERCENTAGE) / BASE;
            _max = _max < 500 ether ? 500 ether : _max;
            _maxBurn = _max;
            _maxMint = _max;
            emit UpdateLimits(_maxMint, _maxBurn);
        }
    }

    // VIEW FUNCTIONS

    /// @notice Effective collateral ratio in %, with base 1e8 = 100%
    /// @dev ECR is the percent of DAI you get by redeming SUSD
    /// @return uint256 Effective collateral ratio in percent, with 1e8=100%
    function getECR() public view returns (uint256) {
        uint256 _totalSupply = SUSD.totalSupply();
        uint256 _reserves = TREASURY.totalDAI();
        if (_reserves > _totalSupply) {
            return BASE;
        }

        return (_reserves * BASE) / _totalSupply;
    }

    /// @return maxMint Max amount that can be minted in an interval of 10 minutes
    function maxMint() external view returns (uint256) {
        if (block.timestamp - lastUpdate > UPDATE_INTERVAL) {
            uint256 _ret = (SUSD.totalSupply() * MAX_PERCENTAGE) / BASE;
            return _ret < 500 ether ? 500 ether : _ret;
        }
        return _maxMint;
    }

    /// @return maxBurn Max amount that can be burn in an interval of 10 minutes
    function maxBurn() external view returns (uint256) {
        if (block.timestamp - lastUpdate > UPDATE_INTERVAL) {
            uint256 _ret = (SUSD.totalSupply() * MAX_PERCENTAGE) / BASE;
            return _ret < 500 ether ? 500 ether : _ret;
        }
        return _maxBurn;
    }
}
