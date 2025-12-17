// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../lib/mutable/vault/src/interfaces/IYieldStrategy.sol";

/**
 * @notice Interface for mintable phUSD token
 */
interface IMintableToken {
    function mint(address to, uint256 amount) external;
}

contract PhusdStableMinter is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Immutable phUSD token address
    address public immutable phUSD;

    // Configuration for each registered stablecoin
    struct StablecoinConfig {
        address yieldStrategy;
        uint256 exchangeRate; // 1e18 = 1:1 ratio
        uint8 decimals;
        bool enabled;
    }

    // Mapping of stablecoin address to its configuration
    mapping(address => StablecoinConfig) public stablecoinConfigs;

    // Reverse mapping for withdraw lookup: yieldStrategy => stablecoin token
    mapping(address => address) public yieldStrategyToToken;

    // Events
    event StablecoinEnabledChanged(address indexed stablecoin, bool enabled);

    // Events
    event StablecoinRegistered(
        address indexed stablecoin,
        address indexed yieldStrategy,
        uint256 exchangeRate,
        uint8 decimals
    );
    event ExchangeRateUpdated(address indexed stablecoin, uint256 oldRate, uint256 newRate);
    event PhUSDMinted(
        address indexed user,
        address indexed stablecoin,
        uint256 stablecoinAmount,
        uint256 phUSDAmount
    );
    event TokensDeposited(address indexed yieldStrategy, address indexed token, uint256 amount);
    event WithdrawalExecuted(
        address indexed yieldStrategy,
        address indexed token,
        uint256 amount,
        address indexed recipient
    );
    event ApprovalSet(address indexed token, address indexed yieldStrategy);

    constructor(address _phUSD) Ownable(msg.sender) {
        phUSD = _phUSD;
    }

    // ========== OWNER FUNCTIONS ==========

    /**
     * @notice Register or update a stablecoin with its yield strategy and exchange rate
     * @param stablecoin The stablecoin token address
     * @param yieldStrategy The yield strategy address to deposit into
     * @param exchangeRate The exchange rate (1e18 = 1:1 ratio)
     * @param decimals The number of decimals for the stablecoin
     */
    function registerStablecoin(
        address stablecoin,
        address yieldStrategy,
        uint256 exchangeRate,
        uint8 decimals
    ) external onlyOwner {
        require(stablecoin != address(0), "Zero address stablecoin");
        require(yieldStrategy != address(0), "Zero address yield strategy");

        stablecoinConfigs[stablecoin] = StablecoinConfig({
            yieldStrategy: yieldStrategy,
            exchangeRate: exchangeRate,
            decimals: decimals,
            enabled: true
        });

        // Populate reverse mapping for withdraw lookup
        yieldStrategyToToken[yieldStrategy] = stablecoin;

        emit StablecoinRegistered(stablecoin, yieldStrategy, exchangeRate, decimals);
    }

    /**
     * @notice Update the exchange rate for a registered stablecoin
     * @param stablecoin The stablecoin token address
     * @param newRate The new exchange rate (1e18 = 1:1 ratio)
     */
    function updateExchangeRate(address stablecoin, uint256 newRate) external onlyOwner {
        require(stablecoinConfigs[stablecoin].yieldStrategy != address(0), "Stablecoin not registered");
        uint256 oldRate = stablecoinConfigs[stablecoin].exchangeRate;
        stablecoinConfigs[stablecoin].exchangeRate = newRate;
        emit ExchangeRateUpdated(stablecoin, oldRate, newRate);
    }

    /**
     * @notice Enable or disable minting for a specific stablecoin
     * @param stablecoin The stablecoin token address
     * @param _enabled True to enable minting, false to disable
     */
    function setStablecoinEnabled(address stablecoin, bool _enabled) external onlyOwner {
        require(stablecoinConfigs[stablecoin].yieldStrategy != address(0), "Stablecoin not registered");
        stablecoinConfigs[stablecoin].enabled = _enabled;
        emit StablecoinEnabledChanged(stablecoin, _enabled);
    }

    /**
     * @notice Deposit tokens to yield strategy without minting phUSD (for seeding)
     * @param yieldStrategy The yield strategy to deposit into
     * @param inputToken The token to deposit
     * @param amount The amount to deposit
     */
    function noMintDeposit(address yieldStrategy, address inputToken, uint256 amount)
        external
        onlyOwner
    {
        // Transfer tokens from caller to this contract
        IERC20(inputToken).safeTransferFrom(msg.sender, address(this), amount);

        // Deposit to yield strategy, minter is the recipient
        IYieldStrategy(yieldStrategy).deposit(inputToken, amount, address(this));

        emit TokensDeposited(yieldStrategy, inputToken, amount);
    }

    /**
     * @notice Approve a token for a yield strategy (max approval)
     * @param token The token to approve
     * @param yieldStrategy The yield strategy to approve for
     */
    function approveYS(address token, address yieldStrategy) external onlyOwner {
        IERC20(token).forceApprove(yieldStrategy, type(uint256).max);
        emit ApprovalSet(token, yieldStrategy);
    }

    /**
     * @notice Withdraw all tokens from a yield strategy (for migration)
     * @param yieldStrategy The yield strategy to withdraw from
     * @param recipient The address to receive the withdrawn tokens
     */
    function withdraw(address yieldStrategy, address recipient) external onlyOwner {
        // Look up the token using reverse mapping
        address token = yieldStrategyToToken[yieldStrategy];

        // Query the full balance from yield strategy
        uint256 balance = IYieldStrategy(yieldStrategy).totalBalanceOf(token, address(this));

        // Withdraw the full balance to the specified recipient
        IYieldStrategy(yieldStrategy).withdraw(token, balance, recipient);

        emit WithdrawalExecuted(yieldStrategy, token, balance, recipient);
    }

    // ========== USER FUNCTIONS ==========

    /**
     * @notice Mint phUSD by depositing stablecoins
     * @param stablecoin The stablecoin to deposit
     * @param amount The amount of stablecoin to deposit
     */
    function mint(address stablecoin, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");

        StablecoinConfig memory config = stablecoinConfigs[stablecoin];
        require(config.yieldStrategy != address(0), "Stablecoin not registered");
        require(config.enabled, "Stablecoin minting is paused");

        // Transfer stablecoin from caller to this contract
        IERC20(stablecoin).safeTransferFrom(msg.sender, address(this), amount);

        // Deposit to yield strategy, minter is the recipient
        IYieldStrategy(config.yieldStrategy).deposit(stablecoin, amount, address(this));

        // Calculate phUSD amount using decimal normalization formula
        uint256 phUSDAmount = calculateMintAmount(stablecoin, amount);

        // Mint phUSD to caller
        IMintableToken(phUSD).mint(msg.sender, phUSDAmount);

        emit PhUSDMinted(msg.sender, stablecoin, amount, phUSDAmount);
    }

    /**
     * @notice Calculate the amount of phUSD that will be minted for a given input
     * @param stablecoin The stablecoin being deposited
     * @param inputAmount The amount of stablecoin
     * @return The amount of phUSD that will be minted
     */
    function calculateMintAmount(address stablecoin, uint256 inputAmount)
        public
        view
        returns (uint256)
    {
        StablecoinConfig memory config = stablecoinConfigs[stablecoin];

        // Decimal normalization formula:
        // phUSDAmount = (inputAmount * exchangeRate * 10^(18 - inputDecimals)) / 1e18
        //Note to auditors: we're assuming that there is no stablecoin with more decimals than 18. Currently this is reasonable. 
        //if this changes, it's possible to migrate to a new minter without much trouble so the consequence of being wrong here is not catastrophic
        uint256 decimalAdjustment = 10 ** (18 - config.decimals);
        return (inputAmount * config.exchangeRate * decimalAdjustment) / 1e18;
    }

    // ========== VIEW FUNCTIONS ==========

    /**
     * @notice Get the configuration for a registered stablecoin
     * @param stablecoin The stablecoin token address
     * @return The stablecoin configuration
     */
    function getStablecoinConfig(address stablecoin)
        external
        view
        returns (StablecoinConfig memory)
    {
        return stablecoinConfigs[stablecoin];
    }

    /**
     * @notice Check if a stablecoin is registered
     * @param stablecoin The stablecoin token address
     * @return True if registered, false otherwise
     */
    function isStablecoinRegistered(address stablecoin) external view returns (bool) {
        return stablecoinConfigs[stablecoin].yieldStrategy != address(0);
    }
}
