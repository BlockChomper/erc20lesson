// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/VulnerableToken.sol";
import "../src/SafeToken.sol";
import "../src/Attacker.sol";

contract ApprovalAttackTest is Test {
    VulnerableToken public vulnerableToken;
    SafeToken public safeToken;
    Attacker public attacker;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public mallory = address(0x3);  // Attacker's EOA
    
    uint256 public initialSupply = 1000000;
    
    function setUp() public {
        console.log("\n=== SETTING UP TEST ENVIRONMENT ===");
        console.log("Alice's address:", alice);
        console.log("Bob's address (legitimate spender):", bob);
        console.log("Mallory's address (attacker):", mallory);
        
        // Deploy contracts
        vulnerableToken = new VulnerableToken(initialSupply);
        safeToken = new SafeToken(initialSupply);
        
        console.log("Vulnerable Token deployed at:", address(vulnerableToken));
        console.log("Safe Token deployed at:", address(safeToken));
        
        // Transfer some tokens to Alice
        vulnerableToken.transfer(alice, 10000 * 10**18);
        safeToken.transfer(alice, 10000 * 10**18);
        
        console.log("Transferred 10,000 tokens to Alice on both token contracts");
        console.log("Alice's vulnerable token balance:", vulnerableToken.balanceOf(alice) / 10**18);
        console.log("Alice's safe token balance:", safeToken.balanceOf(alice) / 10**18);
        
        // Deploy the attacker contract as Mallory
        vm.prank(mallory);
        attacker = new Attacker(address(vulnerableToken));
        
        console.log("Attacker contract deployed by Mallory at:", address(attacker));
        console.log("=== SETUP COMPLETE ===\n");
    }
    
    function testApprovalFrontRunningAttack() public {
        console.log("\n=== APPROVAL FRONT-RUNNING ATTACK DEMONSTRATION ===");
        
        // Initial allowance Alice wants to give to the attacker contract
        uint256 initialAllowance = 100 * 10**18;
        
        // New allowance Alice wants to set later
        uint256 newAllowance = 50 * 10**18;
        
        console.log("\n>>> STEP 1: Alice approves attacker contract for 100 tokens <<<");
        console.log("Before approval - Attacker allowance:", vulnerableToken.allowance(alice, address(attacker)) / 10**18);
        
        // Step 1: Alice approves attacker contract for initial allowance
        vm.prank(alice);
        vulnerableToken.approve(address(attacker), initialAllowance);
        
        console.log("After approval - Attacker allowance:", vulnerableToken.allowance(alice, address(attacker)) / 10**18);
        
        // Check that allowance is set correctly
        assertEq(vulnerableToken.allowance(alice, address(attacker)), initialAllowance, "Allowance not set correctly");
        
        console.log("\n>>> STEP 2: Attacker front-runs Alice's second approval with first attack <<<");
        console.log("Before attack - Mallory's balance:", vulnerableToken.balanceOf(mallory) / 10**18);
        console.log("Before attack - Alice's balance:", vulnerableToken.balanceOf(alice) / 10**18);
        
        // Step 2: Alice decides to change attacker's allowance from initialAllowance to newAllowance
        // But before her transaction is mined, attacker front-runs it
        
        // Attacker executes the first part of the attack
        vm.prank(mallory);
        attacker.executeAttack(alice, initialAllowance, mallory);
        
        console.log("After attack - Mallory's balance:", vulnerableToken.balanceOf(mallory) / 10**18);
        console.log("After attack - Alice's balance:", vulnerableToken.balanceOf(alice) / 10**18);
        console.log("After attack - Attacker allowance:", vulnerableToken.allowance(alice, address(attacker)) / 10**18);
        
        // Check that attacker has received the initially approved tokens
        assertEq(vulnerableToken.balanceOf(mallory), initialAllowance, "Attacker did not receive expected tokens from first attack");
        
        // Check that allowance is now 0 after the transferFrom
        assertEq(vulnerableToken.allowance(alice, address(attacker)), 0, "Allowance should be 0 after transferFrom");
        
        console.log("\n>>> STEP 3: Alice's second approve transaction gets mined <<<");
        console.log("Alice changes the approval to 50 tokens, unaware that first approval was already used");
        
        // Step 3: Now Alice's transaction to change allowance executes
        vm.prank(alice);
        vulnerableToken.approve(address(attacker), newAllowance);
        
        console.log("After second approval - Attacker allowance:", vulnerableToken.allowance(alice, address(attacker)) / 10**18);
        
        // Check that allowance is set to new value
        assertEq(vulnerableToken.allowance(alice, address(attacker)), newAllowance, "New allowance not set correctly");
        
        console.log("\n>>> STEP 4: Attacker executes second attack with new allowance <<<");
        console.log("Before second attack - Mallory's balance:", vulnerableToken.balanceOf(mallory) / 10**18);
        
        // Step 4: Attacker executes the second part of the attack
        vm.prank(mallory);
        attacker.executeSecondAttack(alice, mallory);
        
        console.log("After second attack - Mallory's balance:", vulnerableToken.balanceOf(mallory) / 10**18);
        console.log("After second attack - Alice's balance:", vulnerableToken.balanceOf(alice) / 10**18);
        console.log("After second attack - Attacker allowance:", vulnerableToken.allowance(alice, address(attacker)) / 10**18);
        
        // Check that attacker has received both initially approved tokens and new allowance tokens
        assertEq(vulnerableToken.balanceOf(mallory), initialAllowance + newAllowance, 
            "Attacker did not receive expected tokens from both attacks");
        
        // Check that allowance is now 0 after the second transferFrom
        assertEq(vulnerableToken.allowance(alice, address(attacker)), 0, "Allowance should be 0 after second transferFrom");
        
        // Final check: attacker stole more tokens than Alice ever intended to give
        assertEq(vulnerableToken.balanceOf(mallory), 150 * 10**18, "Attacker should have stolen 150 tokens total");
        
        // Alice lost more tokens than she ever intended to allow
        assertEq(vulnerableToken.balanceOf(alice), 10000 * 10**18 - 150 * 10**18, 
            "Alice should have lost 150 tokens total");
        
        console.log("\n>>> ATTACK SUMMARY <<<");
        console.log("Alice only intended to allow 100 tokens maximum");
        console.log("Mallory exploited the approval front-running vulnerability");
        console.log("Mallory stole a total of:", (initialAllowance + newAllowance) / 10**18, "tokens");
        console.log("=== ATTACK DEMONSTRATION COMPLETE ===\n");
    }
    
    function testSafeTokenPreventsAttack() public {
        console.log("\n=== SAFE TOKEN MITIGATION STRATEGIES DEMONSTRATION ===");
        
        // Initial allowance Alice wants to give to Bob
        uint256 initialAllowance = 100 * 10**18;
        
        // New allowance Alice wants to set later
        uint256 newAllowance = 50 * 10**18;
        
        console.log("\n>>> MITIGATION 1: SAFE APPROVE WITH COMPARE-AND-SET <<<");
        console.log("Initial setup: Alice approves Bob for 100 tokens");
        
        // Setup: Alice approves Bob for initial allowance
        vm.prank(alice);
        safeToken.approve(bob, initialAllowance);
        
        console.log("After initial approval - Bob's allowance:", safeToken.allowance(alice, bob) / 10**18);
        
        // Method 1: Use safeApprove with compare-and-set semantics
        // This will fail if the current allowance doesn't match what Alice expects
        console.log("Alice uses safeApprove to change allowance from 100 to 50 tokens");
        console.log("This requires the current allowance to match the expected value");
        
        vm.prank(alice);
        bool success = safeToken.safeApprove(bob, initialAllowance, newAllowance);
        
        console.log("safeApprove result:", success);
        console.log("After safeApprove - Bob's allowance:", safeToken.allowance(alice, bob) / 10**18);
        
        assertTrue(success, "safeApprove should succeed when current value matches");
        
        // Check that allowance was changed successfully
        assertEq(safeToken.allowance(alice, bob), newAllowance, "Safe approve failed to set correct allowance");
        
        // Try with incorrect current value to show that it fails
        console.log("\nAttacker tries to execute safeApprove with incorrect current value:");
        
        vm.prank(mallory);
        vm.expectRevert("Current allowance doesn't match expected value");
        safeToken.safeApprove(bob, 9999, 123);
        
        console.log("As expected, the transaction reverted because the current allowance doesn't match");
        
        console.log("\n>>> MITIGATION 2: SET TO ZERO FIRST PATTERN <<<");
        console.log("Alice first sets Bob's allowance to 100 tokens");
        
        // Method 2: Set allowance to 0 first, then to new value
        // This is the recommended workaround in the article
        vm.prank(alice);
        safeToken.approve(bob, initialAllowance);
        
        console.log("After first approval - Bob's allowance:", safeToken.allowance(alice, bob) / 10**18);
        console.log("Alice sets allowance to 0 first");
        
        vm.prank(alice);
        safeToken.approve(bob, 0);
        
        console.log("After zeroing - Bob's allowance:", safeToken.allowance(alice, bob) / 10**18);
        console.log("Alice then sets allowance to 50 tokens");
        
        vm.prank(alice);
        safeToken.approve(bob, newAllowance);
        
        console.log("After second approval - Bob's allowance:", safeToken.allowance(alice, bob) / 10**18);
        
        // Check that allowance was changed successfully
        assertEq(safeToken.allowance(alice, bob), newAllowance, "Zero-first approve failed to set correct allowance");
        
        console.log("\n>>> MITIGATION 3: INCREMENTAL ALLOWANCE FUNCTIONS <<<");
        console.log("Alice approves Bob for 100 tokens initially");
        
        // Method 3: Use increaseAllowance/decreaseAllowance
        // This avoids the front-running issue by modifying the allowance relative to current value
        vm.prank(alice);
        safeToken.approve(bob, initialAllowance);
        
        console.log("After initial approval - Bob's allowance:", safeToken.allowance(alice, bob) / 10**18);
        console.log("Alice increases Bob's allowance by 50 tokens");
        
        vm.prank(alice);
        safeToken.increaseAllowance(bob, 50 * 10**18);
        
        console.log("After increaseAllowance - Bob's allowance:", safeToken.allowance(alice, bob) / 10**18);
        
        // Check that allowance was increased successfully
        assertEq(safeToken.allowance(alice, bob), 150 * 10**18, "Increased allowance not set correctly");
        
        console.log("Alice decreases Bob's allowance by 30 tokens");
        
        vm.prank(alice);
        safeToken.decreaseAllowance(bob, 30 * 10**18);
        
        console.log("After decreaseAllowance - Bob's allowance:", safeToken.allowance(alice, bob) / 10**18);
        
        // Check that allowance was decreased successfully
        assertEq(safeToken.allowance(alice, bob), 120 * 10**18, "Decreased allowance not set correctly");
        
        // Try to decrease more than available to show safety check
        console.log("\nTry to decrease more than the current allowance:");
        
        vm.prank(alice);
        vm.expectRevert("Decreased allowance below zero");
        safeToken.decreaseAllowance(bob, 200 * 10**18);
        
        console.log("As expected, the transaction reverted because you can't decrease below zero");
        
        console.log("\n>>> SUMMARY OF MITIGATIONS <<<");
        console.log("1. safeApprove: Atomic compare-and-set to ensure current value matches expectations");
        console.log("2. Zero-first pattern: Set allowance to 0 before setting new value");
        console.log("3. Incremental functions: Modify allowance relative to current value");
        console.log("=== MITIGATION DEMONSTRATION COMPLETE ===\n");
    }
} 