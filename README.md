# Inheritance Contract

Inheritance contract that allows an owner to designate an heir who can claim ownership of the contract and its ETH balance if the owner fails to withdraw funds for 30 consecutive days.

## Key Features

- **30-Day Inactivity Period**: Heir can claim ownership after owner hasn't withdrawn for 30 days
- **Heartbeat Mechanism**: Owner can withdraw 0 ETH to reset the timer without moving funds
- **Heir Management**: Owner can update the designated heir at any time
- **Security First**: Includes reentrancy protection and prevents self-inheritance
- **Inheritance Chain**: New owner must designate a new heir to continue the inheritance mechanism

## How It Works

1. **Deployment**: Contract is deployed with an initial heir address
2. **Normal Operation**: Owner withdraws ETH as needed (resets the 30-day timer)
3. **Inactivity**: If owner doesn't withdraw for 30+ days, heir can claim ownership
4. **Ownership Transfer**: Heir becomes the new owner and must set a new heir

## Core Functions

### Owner Functions

- `withdraw(uint256 amount)` - Withdraw ETH (0 amount = heartbeat)
- `setHeir(address newHeir)` - Update the designated heir

### Heir Functions

- `claimOwnership(address newHeir)` - Claim ownership after 30 days of owner inactivity

### View Functions

- `getBalance()` - Returns contract ETH balance
- `getTimeUntilClaimable()` - Returns seconds until heir can claim
- `canHeirClaim()` - Returns true if heir can currently claim ownership
