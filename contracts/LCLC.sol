// LCLC.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Import OpenZeppelin contracts for ERC20 standard and access control
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LCLC (Life Change - Lucky Coin)
 * @dev LCLC is a token created to support a decentralized financial ecosystem. 
 *      It has unique functionalities such as staking, donations, and weekly lottery-based prize distributions.
 *      The fractional unit of LCLC is called "LUCK".
 */
contract LCLC is ERC20, Ownable {
    // Constants
    uint256 public constant INITIAL_SUPPLY = 0; // 2 LCLC with 18 decimals
    // Tracks 
    mapping(address => bool) private hasBalance; // Tracks addresses that currently have a balance
    mapping(address => uint256) private userBalances; // Tracks the balances of each user
    address[] private users; // List of all users with non-zero balances
    // State variables
    address public developer; // Address of the developer
    address public vaultManager; // Address of the VaultManager contract
    address public pendingNewOwner;
    address public pendingNewDeveloper;

    uint256 public ownerChangeRequestTime;
    uint256 public developerChangeRequestTime;

    uint256 private constant CHANGE_REQUEST_DELAY = 90 days; // 90 days

    // Events
    event DeveloperChanged(address indexed oldDeveloper, address indexed newDeveloper);
    event OwnerChangeRequested(address indexed requester, address indexed newOwner);
    event DeveloperChangeRequested(address indexed requester, address indexed newDeveloper);
    event OwnerChangeCanceled(address indexed currentOwner);
    event DeveloperChangeCanceled(address indexed currentDeveloper);

    /**
     * @notice Constructor to deploy the LCLC token.
     * @param initialOwner The initial owner of the contract (passed to the Ownable constructor).
     */
    constructor(address initialOwner) ERC20("Life Change - Lucky Coin", "LCLC") Ownable(initialOwner) {
        // Set developer to the deployer's address
        developer = msg.sender;

        // Mint initial supply to the owner
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @notice Override the decimals function to return 18, standard for ERC20 tokens.
     *         The smallest fractional unit of LCLC is called "LUCK".
     */
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /**
     * @notice Modifier to restrict access to developer-only functions.
     */
    modifier onlyDeveloper() {
        require(msg.sender == developer, "Caller is not the developer");
        _;
    }

    function _mint(address account, uint256 amount) internal override {
        super._mint(account, amount);
        _trackUserBalance(account, balanceOf(account));
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        super._transfer(sender, recipient, amount);
        _trackUserBalance(sender, balanceOf(sender));
        _trackUserBalance(recipient, balanceOf(recipient));
    }

    function _trackUserBalance(address user, uint256 balance) internal {
        if (balance > 0 && !hasBalance[user]) {
            hasBalance[user] = true;
            users.push(user);
        } else if (balance == 0 && hasBalance[user]) {
            hasBalance[user] = false;
            _removeUser(user);
        }
        userBalances[user] = balance;
    }

    function _removeUser(address user) internal {
        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == user) {
                users[i] = users[users.length - 1];
                users.pop();
                break;
            }
        }
    }

    function getUsers() external view returns (address[] memory) {
        return users;
    }

    function getUserBalance(address user) external view returns (uint256) {
        return userBalances[user];
    }

    function setVaultManager(address _vaultManager) external onlyOwner {
        require(_vaultManager != address(0), "VaultManager address cannot be zero");
        vaultManager = _vaultManager;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == vaultManager, "Caller is not the VaultManager");
        _mint(to, amount);
    }

    function requestOwnerChange(address _newOwner) external onlyDeveloper {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(ownerChangeRequestTime == 0, "Owner change already requested");
        pendingNewOwner = _newOwner;
        ownerChangeRequestTime = block.timestamp;
        emit OwnerChangeRequested(msg.sender, _newOwner);
    }

    function cancelOwnerChange() external onlyOwner {
        require(ownerChangeRequestTime > 0, "No owner change request pending");
        pendingNewOwner = address(0);
        ownerChangeRequestTime = 0;
        emit OwnerChangeCanceled(msg.sender);
    }

    function finalizeOwnerChange() external onlyDeveloper {
        require(ownerChangeRequestTime > 0, "No owner change request pending");
        require(block.timestamp >= ownerChangeRequestTime + CHANGE_REQUEST_DELAY, "Owner change delay not met");
        address oldOwner = owner();
        address newOwner = pendingNewOwner;
        _transferOwnership(newOwner);
        pendingNewOwner = address(0);
        ownerChangeRequestTime = 0;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function requestDeveloperChange(address _newDeveloper) external onlyOwner {
        require(_newDeveloper != address(0), "New developer cannot be zero address");
        require(developerChangeRequestTime == 0, "Developer change already requested");
        pendingNewDeveloper = _newDeveloper;
        developerChangeRequestTime = block.timestamp;
        emit DeveloperChangeRequested(msg.sender, _newDeveloper);
    }

    function cancelDeveloperChange() external onlyDeveloper {
        require(developerChangeRequestTime > 0, "No developer change request pending");
        pendingNewDeveloper = address(0);
        developerChangeRequestTime = 0;
        emit DeveloperChangeCanceled(msg.sender);
    }

    function finalizeDeveloperChange() external onlyOwner {
        require(developerChangeRequestTime > 0, "No developer change request pending");
        require(block.timestamp >= developerChangeRequestTime + CHANGE_REQUEST_DELAY, "Developer change delay not met");
        address oldDeveloper = developer;
        address newDeveloper = pendingNewDeveloper;
        developer = newDeveloper;
        pendingNewDeveloper = address(0);
        developerChangeRequestTime = 0;
        emit DeveloperChanged(oldDeveloper, newDeveloper);
    }
}
