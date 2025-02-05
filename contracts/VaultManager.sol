// VaultManager.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IVault {
    function deposit(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function getProfit(address account) external view returns (uint256);
}

interface IPrizeManager {
    function updateWeeklyProfits(uint256 profits, uint256 totalInvested, uint256 reinvested) external;
    function emitWeeklyReport(uint256 totalInvested, uint256 weeklyProfit) external;
}

contract VaultManager is Ownable {
    address public prizeManager;

    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant SUSD = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;

    address public constant YCRV_VAULT = 0x5533ed0a3b83F70c3c4a1f69Ef5546D3D4713E44;

    struct DepositInfo {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => mapping(address => DepositInfo)) public userDeposits;
    mapping(address => uint256) public releasedTokens;

    uint256 private constant YEAR_IN_SECONDS = 365 * 24 * 3600; // Seconds in a year
    uint256 private constant NASICOIN_RATE = 1e18 / YEAR_IN_SECONDS; // 1 NASICOIN per stablecoin held for a year
    uint256 private constant DONATION_RATE = 100 * 1e18; // 100 NASICOIN per donated stablecoin

    event DepositMade(address indexed user, address indexed token, uint256 amount, uint256 timestamp);
    event WithdrawalCompleted(address indexed user, address indexed token, uint256 amount, uint256 extraTokens);
    event WeeklyReport(
        uint256 totalInvested,
        uint256 weeklyProfit,
        uint256 lowPrizeRemaining,
        uint256 middlePrizeRemaining,
        uint256 highPrizeRemaining,
        uint256 superPrizeRemaining
    );
    event DonationMade(address indexed user, address indexed token, uint256 amount, uint256 nasicReward);
    event TokensMintedBeforeDraw(uint256 totalMinted);

    constructor(address _prizeManager, address initialOwner) Ownable(initialOwner) {
        require(_prizeManager != address(0), "Invalid PrizeManager address");
        prizeManager = _prizeManager;
    }

    function depositToUSDT(uint256 amount) external {
        depositToVault(USDT, amount);
    }

    function depositToUSDC(uint256 amount) external {
        depositToVault(USDC, amount);
    }

    function depositToDAI(uint256 amount) external {
        depositToVault(DAI, amount);
    }

    function depositToSUSD(uint256 amount) external {
        depositToVault(SUSD, amount);
    }

    function donateUSDT(uint256 amount) external {
        donateToVault(USDT, amount);
    }

    function donateUSDC(uint256 amount) external {
        donateToVault(USDC, amount);
    }

    function donateDAI(uint256 amount) external {
        donateToVault(DAI, amount);
    }

    function donateSUSD(uint256 amount) external {
        donateToVault(SUSD, amount);
    }

    function depositToVault(address token, uint256 amount) public {
        require(token == USDT || token == USDC || token == DAI || token == SUSD, "Unsupported token");
        require(amount > 0, "Amount must be greater than zero");

        DepositInfo storage userInfo = userDeposits[msg.sender][token];
        userInfo.amount += amount;
        userInfo.timestamp = block.timestamp;

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(YCRV_VAULT, amount);
        IVault(YCRV_VAULT).deposit(amount);

        emit DepositMade(msg.sender, token, amount, block.timestamp);
    }

    function donateToVault(address token, uint256 amount) public {
        require(token == USDT || token == USDC || token == DAI || token == SUSD, "Unsupported token");
        require(amount > 0, "Amount must be greater than zero");

        // Transfer tokens to the vault
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(YCRV_VAULT, amount);
        IVault(YCRV_VAULT).deposit(amount);

        // Mint NASICOIN reward equivalent to 100x the donation
        uint256 nasicReward = amount * DONATION_RATE;
        releasedTokens[msg.sender] += nasicReward;

        emit DonationMade(msg.sender, token, amount, nasicReward);
    }

    function withdrawFunds(address token, uint256 amount) external {
        DepositInfo storage userInfo = userDeposits[msg.sender][token];
        require(userInfo.amount >= amount, "Insufficient balance");
        require(block.timestamp >= userInfo.timestamp + 7 * 24 * 3600, "Withdrawal locked for 7 days");

        userInfo.amount -= amount;

        uint256 timeHeld = block.timestamp - userInfo.timestamp;
        uint256 extraTokens = (timeHeld * NASICOIN_RATE * amount) / 1e18;

        releasedTokens[msg.sender] += extraTokens;

        IERC20(token).transfer(msg.sender, amount);

        emit WithdrawalCompleted(msg.sender, token, amount, extraTokens);
    }

    function mintTokensBeforeDraw() external onlyOwner {
        uint256 totalMinted = 0;
        for (address account = address(0); account != address(0); account = address(uint160(account) + 1)) {
            uint256 tokens = releasedTokens[account];
            if (tokens > 0) {
                releasedTokens[account] = 0;
                totalMinted += tokens;
            }
        }
        emit TokensMintedBeforeDraw(totalMinted);
    }

    function calculateWeeklyProfits() external onlyOwner {
        uint256 profits = IVault(YCRV_VAULT).getProfit(address(this));
        uint256 totalInvested = IVault(YCRV_VAULT).balanceOf(address(this));
        uint256 reinvested = (profits * 50) / 100;

        IPrizeManager(prizeManager).updateWeeklyProfits(profits, totalInvested, reinvested);

        emit WeeklyReport(
            totalInvested,
            profits,
            0, // Placeholder for lowPrize remaining
            0, // Placeholder for middlePrize remaining
            0, // Placeholder for highPrize remaining
            0  // Placeholder for superPrize remaining
        );
    }

}
