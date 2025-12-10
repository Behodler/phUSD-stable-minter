// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../lib/mutable/vault/src/interfaces/IYieldStrategy.sol";

contract PhusdStableMinter is Ownable {
    // Immutable phUSD token address
    address public immutable phUSD;

    // Configuration for each registered stablecoin
    struct StablecoinConfig {
        address yieldStrategy;
        uint256 exchangeRate; // 1e18 = 1:1 ratio
        uint8 decimals;
    }

    // Mapping of stablecoin address to its configuration
    mapping(address => StablecoinConfig) public stablecoinConfigs;

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
        revert("not implemented");
    }

    /**
     * @notice Update the exchange rate for a registered stablecoin
     * @param stablecoin The stablecoin token address
     * @param newRate The new exchange rate (1e18 = 1:1 ratio)
     */
    function updateExchangeRate(address stablecoin, uint256 newRate) external onlyOwner {
        revert("not implemented");
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
        revert("not implemented");
    }

    /**
     * @notice Approve a token for a yield strategy (max approval)
     * @param token The token to approve
     * @param yieldStrategy The yield strategy to approve for
     */
    function approveYS(address token, address yieldStrategy) external onlyOwner {
        revert("not implemented");
    }

    /**
     * @notice Withdraw all tokens from a yield strategy (for migration)
     * @param yieldStrategy The yield strategy to withdraw from
     * @param recipient The address to receive the withdrawn tokens
     */
    function withdraw(address yieldStrategy, address recipient) external onlyOwner {
        revert("not implemented");
    }

    // ========== USER FUNCTIONS ==========

    /**
     * @notice Mint phUSD by depositing stablecoins
     * @param stablecoin The stablecoin to deposit
     * @param amount The amount of stablecoin to deposit
     */
    function mint(address stablecoin, uint256 amount) external {
        revert("not implemented");
    }

    /**
     * @notice Calculate the amount of phUSD that will be minted for a given input
     * @param stablecoin The stablecoin being deposited
     * @param inputAmount The amount of stablecoin
     * @return The amount of phUSD that will be minted
     */
    function calculateMintAmount(address stablecoin, uint256 inputAmount)
        external
        view
        returns (uint256)
    {
        return 0;
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
