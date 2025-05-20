# ERC20 Approval Front-Running Attack Demo

A comprehensive demonstration of the ERC20 approval front-running vulnerability with working code examples and mitigation strategies.

## Overview

This project provides a complete educational toolkit for understanding, demonstrating, and mitigating the ERC20 approval front-running attack. The repository includes:

- Vulnerable ERC20 implementation
- Attack demonstration contract
- Secure ERC20 implementation with multiple mitigation strategies
- Complete test suite showing attack vectors
- Interactive script for real-world demonstration

## The Vulnerability Explained

The ERC20 standard's `approve` function contains a critical vulnerability when used to modify existing allowances. The vulnerability occurs in this common scenario:

1. Alice approves Bob for 100 tokens
2. Later, Alice wants to change Bob's approval to 50 tokens
3. Bob observes Alice's pending transaction
4. Bob front-runs Alice's transaction, using the current 100 token approval
5. Alice's transaction completes, giving Bob a fresh 50 token approval
6. Result: Bob extracts 150 tokens total, though Alice never intended to allow more than 100

## Smart Contracts

| File | Description |
|------|-------------|
| [VulnerableToken.sol](src/VulnerableToken.sol) | Standard ERC20 implementation vulnerable to front-running |
| [Attacker.sol](src/Attacker.sol) | Contract that demonstrates the attack execution |
| [SafeToken.sol](src/SafeToken.sol) | Enhanced ERC20 with three different mitigation approaches |

## Mitigation Strategies

The project demonstrates three effective mitigation strategies:

### 1. Zero-First Approach

```solidity
// First set allowance to zero
token.approve(spender, 0);
// Then set to new value
token.approve(spender, newAmount);
```

### 2. Atomic Compare-and-Set

```solidity
function safeApprove(address spender, uint256 currentValue, uint256 amount) public returns (bool) {
    require(allowance[msg.sender][spender] == currentValue, "Current allowance doesn't match");
    allowance[msg.sender][spender] = amount;
    emit Approval(msg.sender, spender, amount);
    return true;
}
```

### 3. Incremental Allowance

```solidity
function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
    allowance[msg.sender][spender] += addedValue;
    emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
    return true;
}

function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
    uint256 currentAllowance = allowance[msg.sender][spender];
    require(currentAllowance >= subtractedValue, "Decreased allowance below zero");
    allowance[msg.sender][spender] = currentAllowance - subtractedValue;
    emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
    return true;
}
```

## Running the Demo

### Installation

```bash
git clone https://github.com/your-username/erc20lesson.git
cd erc20lesson
forge install
```

### Test the Attack

```bash
# Run the attack demonstration test
forge test --match-test testApprovalFrontRunningAttack -v

# Run the mitigation tests
forge test --match-test testSafeTokenPreventsAttack -v
```

### Interactive Demo Script

```bash
# Set up test accounts
export ALICE_PRIVATE_KEY=0x...
export MALLORY_PRIVATE_KEY=0x...

# Run the demo script
forge script script/ApprovalAttackDemo.s.sol:ApprovalAttackDemo --broadcast
```

## Security Recommendations for Developers

1. **For Token Contracts:**
   - Always implement `increaseAllowance()` and `decreaseAllowance()` functions
   - Consider adding a `safeApprove()` function with atomic compare-and-set semantics
   - Emit detailed events that include previous allowance values

2. **For DApp Developers:**
   - Use `increaseAllowance`/`decreaseAllowance` when available
   - Always set approval to zero before setting a new value
   - Consider implementing approval guards in your UI

3. **For Token Users:**
   - Be cautious when approving untrusted contracts/addresses
   - Monitor your token approvals regularly
   - Revoke unused approvals when they're no longer needed

## Additional Resources

- [EIP-20: ERC-20 Token Standard](https://eips.ethereum.org/EIPS/eip-20)
- [ERC20 Approve/TransferFrom Attack Analysis](https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit)
- [OpenZeppelin SafeERC20 Implementation](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol)

## Foundry Development Tools

This project uses [Foundry](https://book.getfoundry.sh/), a fast and modern Ethereum development toolkit:

```bash
# Build contracts
forge build

# Run all tests
forge test

# Format code
forge fmt

# Analyze gas usage
forge snapshot

# Local development node
anvil
```

## License

This project is licensed under MIT.
