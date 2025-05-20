// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title SafeToken
 * @dev ERC20 implementation with mitigations for the approval front-running attack
 */
contract SafeToken {
    string public name = "Safe Token";
    string public symbol = "SAFE";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Standard events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    // Extended events as suggested in the article
    event TransferFrom(address indexed spender, address indexed from, address indexed to, uint256 value);
    event ApprovalWithPrevious(address indexed owner, address indexed spender, uint256 oldValue, uint256 value);

    constructor(uint256 initialSupply) {
        totalSupply = initialSupply * 10**uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address to, uint256 amount) public returns (bool success) {
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @dev Standard approval function, still vulnerable to front-running
     */
    function approve(address spender, uint256 amount) public returns (bool success) {
        uint256 oldAllowance = allowance[msg.sender][spender];
        allowance[msg.sender][spender] = amount;
        
        emit Approval(msg.sender, spender, amount);
        emit ApprovalWithPrevious(msg.sender, spender, oldAllowance, amount);
        
        return true;
    }
    
    /**
     * @dev Secure "compare and set" approve function that mitigates front-running attacks
     * Only changes allowance if current value matches _currentValue
     */
    function safeApprove(address spender, uint256 currentValue, uint256 amount) public returns (bool success) {
        require(allowance[msg.sender][spender] == currentValue, "Current allowance doesn't match expected value");
        
        uint256 oldAllowance = allowance[msg.sender][spender];
        allowance[msg.sender][spender] = amount;
        
        emit Approval(msg.sender, spender, amount);
        emit ApprovalWithPrevious(msg.sender, spender, oldAllowance, amount);
        
        return true;
    }
    
    /**
     * @dev Increase allowance by a specific amount
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool success) {
        uint256 oldAllowance = allowance[msg.sender][spender];
        uint256 newAllowance = oldAllowance + addedValue;
        
        allowance[msg.sender][spender] = newAllowance;
        
        emit Approval(msg.sender, spender, newAllowance);
        emit ApprovalWithPrevious(msg.sender, spender, oldAllowance, newAllowance);
        
        return true;
    }
    
    /**
     * @dev Decrease allowance by a specific amount
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool success) {
        uint256 oldAllowance = allowance[msg.sender][spender];
        require(oldAllowance >= subtractedValue, "Decreased allowance below zero");
        
        uint256 newAllowance = oldAllowance - subtractedValue;
        allowance[msg.sender][spender] = newAllowance;
        
        emit Approval(msg.sender, spender, newAllowance);
        emit ApprovalWithPrevious(msg.sender, spender, oldAllowance, newAllowance);
        
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool success) {
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        emit TransferFrom(msg.sender, from, to, amount);
        
        return true;
    }
} 