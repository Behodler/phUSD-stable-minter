// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PhusdStableMinter.sol";
import "../lib/mutable/vault/src/interfaces/IYieldStrategy.sol";

// Mock ERC20 for testing
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external virtual {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

// Mock phUSD with minting capability
contract MockPhUSD is MockERC20 {
    mapping(address => bool) public minters;

    constructor() MockERC20("Phoenix USD", "phUSD", 18) {}

    function setMinter(address minter, bool authorized) external {
        minters[minter] = authorized;
    }

    function mint(address to, uint256 amount) external override {
        require(minters[msg.sender], "Not authorized to mint");
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}

// Mock YieldStrategy for testing
contract MockYieldStrategy is IYieldStrategy {
    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => bool) public clients;

    function deposit(address token, uint256 amount, address recipient) external {
        MockERC20(token).transferFrom(msg.sender, address(this), amount);
        balances[token][recipient] += amount;
    }

    function withdraw(address token, uint256 amount, address recipient) external {
        balances[token][msg.sender] -= amount;
        MockERC20(token).transfer(recipient, amount);
    }

    function balanceOf(address token, address account) external view returns (uint256) {
        return balances[token][account];
    }

    function principalOf(address token, address account) external view returns (uint256) {
        return balances[token][account];
    }

    function totalBalanceOf(address token, address account) external view returns (uint256) {
        return balances[token][account];
    }

    function setClient(address client, bool _auth) external {
        clients[client] = _auth;
    }

    function emergencyWithdraw(uint256) external {}
    function totalWithdrawal(address, address) external {}
    function withdrawFrom(address, address, uint256, address) external {}
}

contract PhusdStableMinterTest is Test {
    PhusdStableMinter public minter;
    MockPhUSD public phUSD;
    MockERC20 public usdc;
    MockERC20 public dai;
    MockYieldStrategy public yieldStrategy;

    address public owner;
    address public user1;
    address public user2;

    uint256 constant EXCHANGE_RATE_1_TO_1 = 1e18;
    uint256 constant EXCHANGE_RATE_095 = 95e16;
    uint256 constant EXCHANGE_RATE_105 = 105e16;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        // Deploy mock tokens
        phUSD = new MockPhUSD();
        usdc = new MockERC20("USD Coin", "USDC", 6);
        dai = new MockERC20("Dai Stablecoin", "DAI", 18);

        // Deploy yield strategy
        yieldStrategy = new MockYieldStrategy();

        // Deploy minter
        minter = new PhusdStableMinter(address(phUSD));

        // Setup permissions
        phUSD.setMinter(address(minter), true);
        yieldStrategy.setClient(address(minter), true);

        // Mint tokens to users for testing
        usdc.mint(user1, 1000000e6); // 1M USDC
        dai.mint(user1, 1000000e18); // 1M DAI
        usdc.mint(user2, 1000000e6);
        dai.mint(user2, 1000000e18);
        // Mint tokens to owner for testing owner functions
        usdc.mint(owner, 1000000e6);
        dai.mint(owner, 1000000e18);
    }

    // ========== REGISTRATION TESTS ==========

    function test_registerStablecoin_CreatesCorrectMappingEntry() public {
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 6);

        PhusdStableMinter.StablecoinConfig memory config = minter.getStablecoinConfig(address(usdc));
        assertEq(config.yieldStrategy, address(yieldStrategy), "YieldStrategy address mismatch");
        assertEq(config.exchangeRate, EXCHANGE_RATE_1_TO_1, "Exchange rate mismatch");
        assertEq(config.decimals, 6, "Decimals mismatch");
    }

    function test_registerStablecoin_RevertsForZeroAddressStablecoin() public {
        vm.expectRevert();
        minter.registerStablecoin(address(0), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 18);
    }

    function test_registerStablecoin_RevertsForZeroAddressYieldStrategy() public {
        vm.expectRevert();
        minter.registerStablecoin(address(usdc), address(0), EXCHANGE_RATE_1_TO_1, 6);
    }

    function test_registerStablecoin_OnlyCallableByOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 6);
    }

    function test_updateExchangeRate_UpdatesExistingRegistration() public {
        // First register
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 6);

        // Then update rate
        minter.updateExchangeRate(address(usdc), EXCHANGE_RATE_095);

        PhusdStableMinter.StablecoinConfig memory config = minter.getStablecoinConfig(address(usdc));
        assertEq(config.exchangeRate, EXCHANGE_RATE_095, "Exchange rate not updated");
    }

    function test_updateExchangeRate_RevertsForUnregisteredStablecoin() public {
        vm.expectRevert();
        minter.updateExchangeRate(address(usdc), EXCHANGE_RATE_095);
    }

    function test_updateExchangeRate_OnlyCallableByOwner() public {
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 6);

        vm.prank(user1);
        vm.expectRevert();
        minter.updateExchangeRate(address(usdc), EXCHANGE_RATE_095);
    }

    // ========== MINT TESTS ==========

    function test_mint_TransfersStablecoinFromCallerToMinter() public {
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 6);
        minter.approveYS(address(usdc), address(yieldStrategy));

        uint256 mintAmount = 1000e6; // 1000 USDC

        vm.startPrank(user1);
        usdc.approve(address(minter), mintAmount);

        uint256 balanceBefore = usdc.balanceOf(user1);
        minter.mint(address(usdc), mintAmount);
        uint256 balanceAfter = usdc.balanceOf(user1);

        assertEq(balanceBefore - balanceAfter, mintAmount, "USDC not transferred from user");
        vm.stopPrank();
    }

    function test_mint_DepositsStablecoinToCorrectYieldStrategy() public {
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 6);
        minter.approveYS(address(usdc), address(yieldStrategy));

        uint256 mintAmount = 1000e6;

        vm.startPrank(user1);
        usdc.approve(address(minter), mintAmount);
        minter.mint(address(usdc), mintAmount);
        vm.stopPrank();

        uint256 strategyBalance = yieldStrategy.balanceOf(address(usdc), address(minter));
        assertEq(strategyBalance, mintAmount, "USDC not deposited to yield strategy");
    }

    function test_mint_CalculatesCorrectPhUSDAmount_1to1_SameDecimals() public {
        minter.registerStablecoin(address(dai), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 18);
        minter.approveYS(address(dai), address(yieldStrategy));

        uint256 mintAmount = 1000e18; // 1000 DAI
        uint256 expectedPhUSD = 1000e18; // 1:1 rate, same decimals

        vm.startPrank(user1);
        dai.approve(address(minter), mintAmount);
        minter.mint(address(dai), mintAmount);
        vm.stopPrank();

        uint256 phUSDBalance = phUSD.balanceOf(user1);
        assertEq(phUSDBalance, expectedPhUSD, "Incorrect phUSD minted (18 decimals)");
    }

    function test_mint_CalculatesCorrectPhUSDAmount_1to1_6Decimals() public {
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 6);
        minter.approveYS(address(usdc), address(yieldStrategy));

        uint256 mintAmount = 1000e6; // 1000 USDC (6 decimals)
        uint256 expectedPhUSD = 1000e18; // 1000 phUSD (18 decimals)

        vm.startPrank(user1);
        usdc.approve(address(minter), mintAmount);
        minter.mint(address(usdc), mintAmount);
        vm.stopPrank();

        uint256 phUSDBalance = phUSD.balanceOf(user1);
        assertEq(phUSDBalance, expectedPhUSD, "Incorrect phUSD minted (6 decimals)");
    }

    function test_mint_CalculatesCorrectPhUSDAmount_CustomExchangeRate() public {
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_095, 6);
        minter.approveYS(address(usdc), address(yieldStrategy));

        uint256 mintAmount = 1000e6; // 1000 USDC
        // Formula: (1000e6 * 95e16 * 10^12) / 1e18 = 950e18
        uint256 expectedPhUSD = 950e18; // 950 phUSD at 0.95 rate

        vm.startPrank(user1);
        usdc.approve(address(minter), mintAmount);
        minter.mint(address(usdc), mintAmount);
        vm.stopPrank();

        uint256 phUSDBalance = phUSD.balanceOf(user1);
        assertEq(phUSDBalance, expectedPhUSD, "Incorrect phUSD minted (custom rate)");
    }

    function test_mint_MintsCorrectPhUSDToCaller() public {
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 6);
        minter.approveYS(address(usdc), address(yieldStrategy));

        uint256 mintAmount = 1000e6;
        uint256 expectedPhUSD = 1000e18;

        vm.startPrank(user1);
        usdc.approve(address(minter), mintAmount);

        uint256 balanceBefore = phUSD.balanceOf(user1);
        minter.mint(address(usdc), mintAmount);
        uint256 balanceAfter = phUSD.balanceOf(user1);

        assertEq(balanceAfter - balanceBefore, expectedPhUSD, "phUSD not minted to caller");
        vm.stopPrank();
    }

    function test_mint_RevertsForUnregisteredStablecoin() public {
        vm.startPrank(user1);
        usdc.approve(address(minter), 1000e6);
        vm.expectRevert();
        minter.mint(address(usdc), 1000e6);
        vm.stopPrank();
    }

    function test_mint_RevertsForZeroAmount() public {
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 6);

        vm.prank(user1);
        vm.expectRevert();
        minter.mint(address(usdc), 0);
    }

    // ========== EXCHANGE RATE CALCULATION TESTS ==========

    function test_calculateMintAmount_ReturnsCorrectAmountFor18DecimalAt1to1() public {
        minter.registerStablecoin(address(dai), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 18);

        uint256 inputAmount = 1000e18;
        uint256 expectedOutput = 1000e18;

        uint256 result = minter.calculateMintAmount(address(dai), inputAmount);
        assertEq(result, expectedOutput, "Calculation incorrect (18 decimals, 1:1)");
    }

    function test_calculateMintAmount_ReturnsCorrectAmountFor6DecimalAt1to1() public {
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 6);

        uint256 inputAmount = 1000e6;
        uint256 expectedOutput = 1000e18;

        uint256 result = minter.calculateMintAmount(address(usdc), inputAmount);
        assertEq(result, expectedOutput, "Calculation incorrect (6 decimals, 1:1)");
    }

    function test_calculateMintAmount_ReturnsCorrectAmountWith095Rate() public {
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_095, 6);

        uint256 inputAmount = 1000e6;
        // (1000e6 * 95e16 * 10^12) / 1e18 = 950e18
        uint256 expectedOutput = 950e18;

        uint256 result = minter.calculateMintAmount(address(usdc), inputAmount);
        assertEq(result, expectedOutput, "Calculation incorrect (0.95 rate)");
    }

    function test_calculateMintAmount_ReturnsCorrectAmountWith105Rate() public {
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_105, 6);

        uint256 inputAmount = 1000e6;
        // (1000e6 * 105e16 * 10^12) / 1e18 = 1050e18
        uint256 expectedOutput = 1050e18;

        uint256 result = minter.calculateMintAmount(address(usdc), inputAmount);
        assertEq(result, expectedOutput, "Calculation incorrect (1.05 rate)");
    }

    // ========== NO-MINT DEPOSIT TESTS ==========

    function test_noMintDeposit_TransfersTokensFromCallerToMinter() public {
        minter.approveYS(address(usdc), address(yieldStrategy));

        uint256 depositAmount = 1000e6;

        usdc.approve(address(minter), depositAmount);
        uint256 balanceBefore = usdc.balanceOf(address(this));
        minter.noMintDeposit(address(yieldStrategy), address(usdc), depositAmount);
        uint256 balanceAfter = usdc.balanceOf(address(this));

        assertEq(balanceBefore - balanceAfter, depositAmount, "Tokens not transferred from caller");
    }

    function test_noMintDeposit_DepositsTokensToSpecifiedYieldStrategy() public {
        minter.approveYS(address(usdc), address(yieldStrategy));

        uint256 depositAmount = 1000e6;

        usdc.approve(address(minter), depositAmount);
        minter.noMintDeposit(address(yieldStrategy), address(usdc), depositAmount);

        uint256 strategyBalance = yieldStrategy.balanceOf(address(usdc), address(minter));
        assertEq(strategyBalance, depositAmount, "Tokens not deposited to yield strategy");
    }

    function test_noMintDeposit_DoesNotMintAnyPhUSD() public {
        minter.approveYS(address(usdc), address(yieldStrategy));

        uint256 depositAmount = 1000e6;

        usdc.approve(address(minter), depositAmount);
        uint256 phUSDBalanceBefore = phUSD.balanceOf(address(this));
        minter.noMintDeposit(address(yieldStrategy), address(usdc), depositAmount);
        uint256 phUSDBalanceAfter = phUSD.balanceOf(address(this));

        assertEq(phUSDBalanceBefore, phUSDBalanceAfter, "phUSD was minted when it should not have been");
    }

    function test_noMintDeposit_OnlyCallableByOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        minter.noMintDeposit(address(yieldStrategy), address(usdc), 1000e6);
    }

    // ========== APPROVAL TESTS ==========

    function test_approveYS_SetsMaxApprovalForTokenOnYieldStrategy() public {
        minter.approveYS(address(usdc), address(yieldStrategy));

        uint256 allowance = usdc.allowance(address(minter), address(yieldStrategy));
        assertEq(allowance, type(uint256).max, "Max approval not set");
    }

    function test_approveYS_OnlyCallableByOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        minter.approveYS(address(usdc), address(yieldStrategy));
    }

    // ========== WITHDRAW TESTS ==========

    function test_withdraw_CallsYieldStrategyWithdrawForFullBalance() public {
        // Setup: deposit some tokens first
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 6);
        minter.approveYS(address(usdc), address(yieldStrategy));

        uint256 depositAmount = 1000e6;
        usdc.approve(address(minter), depositAmount);
        minter.noMintDeposit(address(yieldStrategy), address(usdc), depositAmount);

        // Now withdraw
        minter.withdraw(address(yieldStrategy), user2);

        uint256 remainingBalance = yieldStrategy.balanceOf(address(usdc), address(minter));
        assertEq(remainingBalance, 0, "Yield strategy balance not withdrawn");
    }

    function test_withdraw_SendsWithdrawnTokensToSpecifiedRecipient() public {
        // Setup: deposit some tokens first
        minter.registerStablecoin(address(usdc), address(yieldStrategy), EXCHANGE_RATE_1_TO_1, 6);
        minter.approveYS(address(usdc), address(yieldStrategy));

        uint256 depositAmount = 1000e6;
        usdc.approve(address(minter), depositAmount);
        minter.noMintDeposit(address(yieldStrategy), address(usdc), depositAmount);

        // Now withdraw
        uint256 balanceBefore = usdc.balanceOf(user2);
        minter.withdraw(address(yieldStrategy), user2);
        uint256 balanceAfter = usdc.balanceOf(user2);

        assertEq(balanceAfter - balanceBefore, depositAmount, "Tokens not sent to recipient");
    }

    function test_withdraw_OnlyCallableByOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        minter.withdraw(address(yieldStrategy), user2);
    }
}
