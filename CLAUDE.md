# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Submodule: PhusdStableMinter

This is a Foundry smart contract submodule for the PhusdStableMinter contract.

### Project Purpose

**PhusdStableMinter** is a one-way minting contract that:
- Accepts various stablecoins from users (USDC, DAI, USDT, etc.)
- Mints phUSD (Phoenix USD) tokens at a configurable exchange rate
- Deposits the received stablecoins into registered yield strategies via the vault-RM IYieldStrategy interface
- Does NOT support redemption - this is a one-way mint only

### Architecture Overview

The contract acts as a bridge between users and yield-generating strategies:

```
User → PhusdStableMinter → IYieldStrategy → ERC4626 Vault
     (deposit stablecoin)  (mint phUSD)     (earn yield)
```

**Key Components:**

1. **StablecoinConfig Mapping**: Maps each supported stablecoin to:
   - The IYieldStrategy address that will receive deposits
   - Exchange rate (e.g., 1:1 = 1e18, 0.95:1 = 95e16)
   - Decimal count for proper normalization

2. **Decimal Normalization**: Handles different decimal counts across stablecoins:
   - phUSD has 18 decimals (standard ERC20)
   - USDC/USDT have 6 decimals
   - DAI has 18 decimals
   - Formula: `phUSDAmount = (inputAmount * exchangeRate * 10^(18 - inputDecimals)) / 1e18`

3. **Yield Strategy Integration**: Uses vault-RM's IYieldStrategy interface:
   - `deposit(token, amount, recipient)` - Deposits stablecoins, minter is recipient
   - `totalBalanceOf(token, account)` - Queries balance for withdrawals
   - `withdraw(token, amount, recipient)` - Withdraws to specified recipient

4. **Owner Functions**:
   - Register/update stablecoin configurations
   - Seed yield strategies without minting (no-mint deposits)
   - Approve tokens for yield strategies
   - Withdraw from yield strategies for migrations

### Important Constraints

- **Authorization Required**: The yield strategy must have the minter registered as an authorized client via `setClient()`
- **Minting Permission**: The phUSD token must grant minting permission to this contract
- **One-Way Only**: Users cannot redeem phUSD back to stablecoins through this contract
- **Owner-Controlled Rates**: Only owner can set/update exchange rates (no oracle integration needed for stablecoin-to-stablecoin)

## Dependency Management

### Types of Dependencies

1. **Immutable Dependencies** (lib/immutable/)
   - External libraries and contracts that don't change based on sibling requirements
   - Full source code is available
   - Examples: OpenZeppelin, standard libraries

2. **Mutable Dependencies** (lib/mutable/)
   - Dependencies from sibling submodules
   - ONLY interfaces and abstract contracts are exposed
   - NO implementation details are available
   - Changes to these dependencies must go through the change request process

### Important Rules

- **NEVER** access implementation details of mutable dependencies
- Mutable dependencies only expose interfaces and abstract contracts
- If a feature requires changes to a mutable dependency, add it to the change request queue
- All development must follow Test-Driven Development (TDD) principles using Foundry

### Change Request Process

When a feature requires changes to a mutable dependency:

1. Add the request to `MutableChangeRequests.json` with format:
   ```json
   {
     "requests": [
       {
         "dependency": "dependency-name",
         "changes": [
           {
             "fileName": "ISomeInterface.sol",
             "description": "Plain language description of what needs to change"
           }
         ]
       }
     ]
   }
   ```

2. **STOP WORK** immediately after adding the change request
3. Inform the user that dependency changes are needed
4. Wait for the dependency to be updated before continuing

### Available Commands

- `.claude/commands/add-mutable-dependency.sh <repo>` - Add a mutable dependency (sibling)
- `.claude/commands/add-immutable-dependency.sh <repo>` - Add an immutable dependency
- `.claude/commands/update-mutable-dependency.sh <name>` - Update a mutable dependency
- `.claude/commands/consider-change-requests.sh` - Review and implement sibling change requests

## Project Structure

- `src/` - Solidity source files
- `test/` - Test files (TDD required)
- `script/` - Deployment scripts
- `lib/mutable/` - Mutable dependencies (interfaces only)
- `lib/immutable/` - Immutable dependencies (full source)

## Development Guidelines

### Test-Driven Development (TDD)

**ALL** features, bug fixes, and modifications MUST follow TDD principles:

1. **Write tests first** - Before implementing any feature
2. **Red phase** - Write failing tests that define the expected behavior
3. **Green phase** - Write minimal code to make tests pass
4. **Refactor phase** - Improve code while keeping tests green

### Testing Commands

- `forge test` - Run all tests
- `forge test -vvv` - Run tests with verbose output
- `forge test --match-contract <ContractName>` - Run specific contract tests
- `forge test --match-test <testName>` - Run specific test
- `forge coverage` - Check test coverage

### Other Commands

- `forge build` - Compile contracts
- `forge fmt` - Format Solidity code
- `forge snapshot` - Generate gas snapshots

## Important Reminders

- This submodule operates independently from sibling submodules
- Follow Solidity best practices and naming conventions
- Use Foundry testing tools exclusively (no Hardhat or Truffle)
- If you need to change a mutable dependency, use the change request process
