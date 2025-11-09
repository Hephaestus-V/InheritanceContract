// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title Inheritance
 * @author Varad
 * @notice An inheritance contract where the heir can claim ownership if the owner
 *         doesn't withdraw ETH for more than 30 days
 * @dev Timer only resets on withdrawals (including 0 ETH withdrawals), not on other actions
 */
contract Inheritance {
    // State variables
    address payable public owner;
    address payable public heir;
    uint256 public lastWithdrawal; // Tracks the last withdrawal time
    uint256 public constant INACTIVITY_PERIOD = 30 days;

    // Reentrancy lock
    bool private _locked;

    // Custom errors for gas-efficient reverts
    error InsufficientBalance();
    error OnlyOwner();
    error OnlyHeir();
    error Reentrancy();
    error InvalidHeirAddress();
    error OwnerStillActive();
    error TransferFailed();
    error InvalidCall();

    // Events for tracking important state changes
    event Deposited(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);
    event HeirUpdated(address indexed previousHeir, address indexed newHeir);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Sets up the contract with deployer as owner and initializes the heir
     * @param initialHeir Address that can claim ownership of the contract after withdrawal inactivity period
     */
    constructor(address initialHeir) {
        if (initialHeir == address(0) || initialHeir == msg.sender) revert InvalidHeirAddress();
        owner = payable(msg.sender);
        heir = payable(initialHeir);
        lastWithdrawal = block.timestamp; // Start the timer from deployment
    }

    // Restricts function access to only the current owner
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    // Restricts function access to only the designated heir
    modifier onlyHeir() {
        if (msg.sender != heir) revert OnlyHeir();
        _;
    }

    // To prevent reentrancy attacks
    modifier nonReentrant() {
        if (_locked) revert Reentrancy();
        _locked = true;
        _;
        _locked = false;
    }

    /**
     * @notice Allows owner to designate a new heir who can claim ownership later
     * @dev Does NOT reset the withdrawal timer (only withdrawals reset the timer)
     * @param newHeir Address of the new heir (cannot be zero address or owner themselves)
     */
    function setHeir(address newHeir) external onlyOwner {
        if (newHeir == address(0) || newHeir == owner) revert InvalidHeirAddress();

        address previousHeir = heir;
        heir = payable(newHeir);

        emit HeirUpdated(previousHeir, newHeir);
    }

    /**
     * @notice Withdraw ETH from the contract (owner only)
     * @dev Can be called with 0 amount to just reset the withdrawal timer (heartbeat)
     * @param amount Amount of wei to withdraw (0 is valid for timer reset)
     */
    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        // Check if contract has sufficient balance
        if (amount > address(this).balance) revert InsufficientBalance();

        // Reset the withdrawal timer
        lastWithdrawal = block.timestamp;

        // Only transfer if amount is non-zero
        if (amount > 0) {
            (bool success,) = owner.call{value: amount}("");
            if (!success) revert TransferFailed();
            emit Withdrawn(owner, amount);
        }
        // Note: withdrawing 0 is allowed as a "heartbeat" to reset the timer
    }

    /**
     * @notice Allows heir to claim ownership of the contract after owner hasn't withdrawn for 30 days
     * @dev Heir must provide a new heir address to ensure inheritance chain continues
     * @param newHeir Address that will become the new heir after claiming ownership
     */
    function claimOwnership(address newHeir) external onlyHeir {
        // Verify enough time has passed since last withdrawal
        if (block.timestamp < lastWithdrawal + INACTIVITY_PERIOD) revert OwnerStillActive();

        // Prevent setting invalid heir (prevents self inheritance)
        if (newHeir == address(0) || newHeir == msg.sender) revert InvalidHeirAddress();

        address previousOwner = owner;

        // Transfer ownership to heir
        owner = payable(msg.sender); // msg.sender is heir
        heir = payable(newHeir); // Set new heir to continue the chain
        lastWithdrawal = block.timestamp; // Reset timer for new owner

        emit OwnershipTransferred(previousOwner, msg.sender);
        emit HeirUpdated(msg.sender, newHeir);
    }

    /**
     * @notice Returns the current ETH balance held in the contract
     * @return Current balance in wei
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Calculates time remaining until heir can claim ownership
     * @return Seconds remaining until claimable (0 if already claimable)
     */
    function getTimeUntilClaimable() external view returns (uint256) {
        uint256 claimableTime = lastWithdrawal + INACTIVITY_PERIOD;
        return block.timestamp >= claimableTime ? 0 : claimableTime - block.timestamp;
    }

    /**
     * @notice Checks if the inactivity period has passed
     * @return True if heir can currently claim ownership, false otherwise
     */
    function canHeirClaim() external view returns (bool) {
        return block.timestamp >= lastWithdrawal + INACTIVITY_PERIOD;
    }

    /**
     * @dev Allows contract to receive ETH via direct transfers
     */
    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @dev Fallback function handles calls with data
     *      Accepts ETH but rejects calls without value
     */
    fallback() external payable {
        if (msg.value == 0) revert InvalidCall();
        emit Deposited(msg.sender, msg.value);
    }
}

