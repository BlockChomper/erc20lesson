// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/VulnerableToken.sol";
import "../src/SafeToken.sol";
import "../src/Attacker.sol";

/**
 * @title ApprovalAttackDemo
 * @dev Script to demonstrate the ERC20 approval front-running attack in sequence
 * Run with forge script script/ApprovalAttackDemo.s.sol:ApprovalAttackDemo --broadcast
 */
contract ApprovalAttackDemo is Script {
    VulnerableToken public vulnerableToken;
    SafeToken public safeToken;
    Attacker public attacker;
    
    address public alice;
    address public mallory;
    
    uint256 public initialSupply = 1000000;
    
    function run() public {
        // Setup accounts
        uint256 alicePrivateKey = vm.envUint("ALICE_PRIVATE_KEY");
        uint256 malloryPrivateKey = vm.envUint("MALLORY_PRIVATE_KEY");
        
        alice = vm.addr(alicePrivateKey);
        mallory = vm.addr(malloryPrivateKey);
        
        console.log("Alice address:", alice);
        console.log("Mallory address:", mallory);
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        // Step 1: Deploy the tokens and transfer some to Alice
        vulnerableToken = new VulnerableToken(initialSupply);
        safeToken = new SafeToken(initialSupply);
        
        console.log("Vulnerable Token deployed at:", address(vulnerableToken));
        console.log("Safe Token deployed at:", address(safeToken));
        
        // Transfer tokens to Alice
        vulnerableToken.transfer(alice, 10000 * 10**18);
        safeToken.transfer(alice, 10000 * 10**18);
        
        vm.stopBroadcast();
        
        // Step 2: Mallory deploys the attacker contract
        vm.startBroadcast(malloryPrivateKey);
        
        attacker = new Attacker(address(vulnerableToken));
        console.log("Attacker contract deployed at:", address(attacker));
        
        vm.stopBroadcast();
        
        // Step 3: Alice approves the attacker contract for 100 tokens
        vm.startBroadcast(alicePrivateKey);
        
        uint256 initialAllowance = 100 * 10**18;
        vulnerableToken.approve(address(attacker), initialAllowance);
        console.log("Alice approved attacker for:", initialAllowance / 10**18, "tokens");
        
        vm.stopBroadcast();
        
        // Step 4: Demonstrate front-running by Mallory
        vm.startBroadcast(malloryPrivateKey);
        
        console.log("Mallory front-runs Alice's second approve transaction");
        attacker.executeAttack(alice, initialAllowance, mallory);
        console.log("Mallory stole first batch of tokens:", initialAllowance / 10**18);
        
        vm.stopBroadcast();
        
        // Step 5: Alice's second approve transaction gets mined
        vm.startBroadcast(alicePrivateKey);
        
        uint256 newAllowance = 50 * 10**18;
        console.log("Alice tries to change allowance to:", newAllowance / 10**18, "tokens");
        vulnerableToken.approve(address(attacker), newAllowance);
        
        vm.stopBroadcast();
        
        // Step 6: Mallory steals the second batch of tokens
        vm.startBroadcast(malloryPrivateKey);
        
        console.log("Mallory steals the second batch of tokens");
        attacker.executeSecondAttack(alice, mallory);
        console.log("Mallory stole second batch of tokens:", newAllowance / 10**18);
        
        uint256 totalStolen = initialAllowance + newAllowance;
        console.log("Total tokens stolen by Mallory:", totalStolen / 10**18);
        
        vm.stopBroadcast();
        
        // Step 7: Show how to safely change approvals with SafeToken
        vm.startBroadcast(alicePrivateKey);
        
        console.log("\n--- SAFE TOKEN DEMONSTRATION ---");
        
        // Method 1: Set to zero first
        console.log("Method 1: Set to zero first");
        safeToken.approve(mallory, initialAllowance);
        console.log("Alice approves Mallory for:", initialAllowance / 10**18, "tokens");
        safeToken.approve(mallory, 0);
        console.log("Alice sets allowance to 0 first");
        safeToken.approve(mallory, newAllowance);
        console.log("Alice changes allowance to:", newAllowance / 10**18, "tokens");
        
        // Method 2: Use safeApprove
        console.log("\nMethod 2: Use atomic compare-and-set");
        safeToken.approve(mallory, initialAllowance);
        console.log("Alice approves Mallory for:", initialAllowance / 10**18, "tokens");
        safeToken.safeApprove(mallory, initialAllowance, newAllowance);
        console.log("Alice safely changes allowance to:", newAllowance / 10**18, "tokens");
        
        // Method 3: Use increaseAllowance/decreaseAllowance
        console.log("\nMethod 3: Use increaseAllowance/decreaseAllowance");
        safeToken.approve(mallory, initialAllowance);
        console.log("Alice approves Mallory for:", initialAllowance / 10**18, "tokens");
        safeToken.decreaseAllowance(mallory, 50 * 10**18);
        console.log("Alice safely decreases allowance by 50 tokens");
        
        vm.stopBroadcast();
    }
} 