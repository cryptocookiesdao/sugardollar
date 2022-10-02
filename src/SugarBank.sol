// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {IERC20, IERC20Burneable} from "./interfaces/IERC20Burneable.sol";
import {IGame} from "./interfaces/IGame.sol";
import {IBankVault} from "./interfaces/IBankVault.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {ICollateralPolicy} from "./interfaces/ICollateralPolicy.sol";
import {IOwnable} from "./interfaces/IOwnable.sol";

/// @title SugarBank
/// @dev This contract manages the minting and redeeming of sUSD tokens.
contract SugarBank is Ownable {
    using SafeERC20 for IERC20;

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

    /**
     * EVENTS *
     */

    event UpdateLimits(uint256 _maxMint, uint256 _maxBurn);
    event TimelockMigration(Migration pendingMigration);
    event TimelockMigrate(Migration pendingMigration);
    event CollateralPolicyUpdate(address collateralPolicy);
    event OracleUpdate(address oracle);

    event NameUint(string name, uint256 value);

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
        collateralPolicy = ICollateralPolicy(_collateralPolicy);
        emit CollateralPolicyUpdate(_collateralPolicy);
    }

    /// @notice Update the current oracle
    function setOracle(address _oracle) external onlyOwner {
        oracle = IOracle(_oracle);
        emit OracleUpdate(_oracle);
    }

    /// @notice Update the mint&burn fees.
    function updateBurnMintFees(uint256 _burnFee, uint256 _mintFee) external onlyOwner {
        require(_burnFee <= 5_00_0000, "ERR: Burn fee > 5%");
        require(_mintFee <= 5_00_0000, "ERR: Burn fee > 5%");
        mintFee = _mintFee;
        burnFee = _burnFee;
    }

    /// @notice Prepare a migration, this is use to transfer ownership of a contract that is own by the bank
    ///         This is useful for the migration of the contracts to a new sugarbank version
    function migrate(address _contract, address _newOwner) external onlyOwner {
        pendingMigration[_contract] =
            Migration({targetContract: _contract, newOwner: _newOwner, execTimestamp: block.timestamp + 7 days});

        emit TimelockMigration(pendingMigration[_contract]);
    }

    function migrateInTimelock(address _contract) external onlyOwner {
        Migration memory _pendingMigration = pendingMigration[_contract];
        require(_pendingMigration.targetContract == _contract, "ERR: Invalid migration id");
        require(_pendingMigration.execTimestamp < block.timestamp, "ERR: wait for Migration");
        IOwnable(_pendingMigration.targetContract).transferOwnership(_pendingMigration.newOwner);
        emit TimelockMigrate(_pendingMigration);
        delete pendingMigration[_contract];
    }

    // user functions

    function mintZap(uint256 _amountDAI, uint256 _minAmountOut) external {
        emit NameUint("mintZap in", _amountDAI);
        emit NameUint("mintZap minout", _minAmountOut);
        // get the current target collateral ratio
        uint256 _tcr = collateralPolicy.updateAndGet();

        uint256 _amountDAItoCkie = (_amountDAI * (BASE - _tcr)) / BASE;

        if (_amountDAItoCkie == 0) {
            emit NameUint("NO HACE ZAP  minout", _minAmountOut);
            mint(_amountDAI, 0, _minAmountOut);
            return;
        }
        
        emit NameUint("_amountDAItoCkie", _amountDAItoCkie);

        DAI.safeTransferFrom(msg.sender, address(this), _amountDAItoCkie);

        uint256[] memory amounts =
            ROUTER.swapExactTokensForTokens(_amountDAItoCkie, 0, _pathDaiCkie, msg.sender, block.timestamp + 60);

        mint(_amountDAI - _amountDAItoCkie, amounts[2], _minAmountOut);
    }

    // this will mint new SUSD
    function mint(uint256 _amountDAI, uint256 _amountCOOKIE, uint256 _minAmountOut) public {
        _update();
        // cache mint limits
        uint256 maxMint_ = _maxMint;
        require(maxMint_ != 0, "Max mint per interval reach");
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
            amountToMint = (_amountDAI * daiPrice) / 1e8;

            // Amount of DAI to back the new SUSD
            uint256 daiToTransfer = _amountDAI;

            if (amountToMint > maxMint_) {
                amountToMint = maxMint_;
                daiToTransfer = (amountToMint * 1e8) / daiPrice;
            }
            require(daiToTransfer != 0, "Price error");

            emit NameUint("TRANSFER DAI", daiToTransfer);

            DAI.safeTransferFrom(msg.sender, address(TREASURY), daiToTransfer);
        } else {
            uint256 cookieUSDPrice = oracle.cookiePrice();
            amountToMint = (_amountDAI * daiPrice) / _tcr;
            uint256 targetAmount2 = (_amountCOOKIE * cookieUSDPrice) / (BASE - _tcr);
            

            emit NameUint("targetAmount", amountToMint);
            emit NameUint("targetAmount2", targetAmount2);

            amountToMint = (amountToMint < targetAmount2) ? amountToMint : targetAmount2;

            emit NameUint("amountToMint", amountToMint);

            if (amountToMint > maxMint_) {
                amountToMint = maxMint_;
            }

            emit NameUint("amountToMint", amountToMint);

            _amountCOOKIE = (amountToMint * (BASE - _tcr)) / cookieUSDPrice;
            _amountDAI = (amountToMint * _tcr) / (daiPrice);

            emit NameUint("_amountCOOKIE", _amountCOOKIE);
            emit NameUint("_amountDAI", _amountDAI);

            DAI.safeTransferFrom(msg.sender, address(TREASURY), _amountDAI);
            CKIE.burnFrom(msg.sender, _amountCOOKIE);
        }

        if (amountToMint > 0) {
            unchecked {
                /*
                uint256 _out = (amountToMint * (BASE - mintFee)) / BASE;
                require(_minAmountOut <= _out, "Price slippage check");
                SUSD.mint(msg.sender, _out);
                if (amountToMint > _out) {
                    SUSD.mint(DEV, amountToMint - _out);
                }
                */

                require((_minAmountOut * (BASE - mintFee)) / BASE <= amountToMint, "Price slippage check");

                pending[msg.sender] += amountToMint;
                waitBlock[msg.sender] = block.number + 1;

                // Burn & Mint limits will be updated
                _maxMint -= amountToMint;
            }
        }

        emit UpdateLimits(_maxMint, _maxBurn);
    }

    function claim() external {
        claim(msg.sender);
    }

    function claim(address account) public {
        require(account != address(0), "!address(0)");
        uint256 _pending = pending[account];
        require(waitBlock[account] > 0, "Nothing to claim");
        require(waitBlock[account] < block.number, "Wait more blocks");

        uint256 _out = (_pending * (BASE - mintFee)) / BASE;
        delete pending[account];
        delete waitBlock[account];
        SUSD.mint(account, _out);
        SUSD.mint(DEV, _pending - _out);
    }

    ///@notice This will burn SUSD and give DAI and cookie to te user
    function redeem(uint256 amount) external {
        require(amount != 0, "ERR: Amount is 0");
        _update();
        // cache max burn limits
        uint256 maxBurn_ = _maxBurn;
        require(maxBurn_ != 0, "Max mint per interval reach");

        if (amount > maxBurn_) {
            amount = maxBurn_;
        }

        unchecked {
            _maxBurn -= amount;
            // maxMint += amount;
        }

        uint256 totalBurnAmount = amount;

        unchecked {
            amount = (totalBurnAmount * (BASE - burnFee)) / BASE;
            emit NameUint("fee SUSD", totalBurnAmount - amount);
            SUSD.transferFrom(msg.sender, address(TREASURY), totalBurnAmount - amount);
        }
        
        // Effective Collateral Ratio en % con base 1e8 = 100%, need get it before burn
        uint256 _ecr = getECR();


        emit NameUint("burn SUSD", amount);
        SUSD.burnFrom(msg.sender, amount);

        // oracle get DAI price in USD (chainlink)
        uint256 daiPrice = oracle.daiPrice();

        // total DAI en base 1e18
        // 1e18 * 1e8 / 1e6 * 100 =
        uint256 totalDAI = (amount * _ecr) / BASE;

        TREASURY.transferDAI(msg.sender, totalDAI);
        if (_ecr < BASE) {
            uint256 cookieUSDPrice = oracle.cookiePrice();
            // min cookie USD price = 10000
            if (cookieUSDPrice < 10000) {
                cookieUSDPrice = 10000;
            }
            emit NameUint("cookie in USD", cookieUSDPrice);
            emit NameUint("debo", (amount * (BASE - _ecr)) / BASE);
            
            amount = amount - ((daiPrice * totalDAI) / BASE);
            GAME.sugarBankMint(msg.sender, (amount * BASE) / cookieUSDPrice);
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
