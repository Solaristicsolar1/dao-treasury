import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can add DAO members",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'add-member', [
                types.principal(wallet1.address),
                types.uint(100)
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result, '(ok true)');
        
        // Verify member was added
        let getMember = chain.callReadOnlyFn('dao-treasury', 'get-member', [
            types.principal(wallet1.address)
        ], deployer.address);
        
        assertEquals(getMember.result, '(some {joined-at: u1, voting-weight: u100})');
    },
});

Clarinet.test({
    name: "Only contract owner can add members",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'add-member', [
                types.principal(wallet2.address),
                types.uint(50)
            ], wallet1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result, '(err u401)'); // ERR-UNAUTHORIZED
    },
});

Clarinet.test({
    name: "DAO members can create proposals",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // First add member
        let addMember = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'add-member', [
                types.principal(wallet1.address),
                types.uint(100)
            ], deployer.address)
        ]);
        
        // Fund the contract
        let fundContract = chain.mineBlock([
            Tx.transferSTX(1000000, `${deployer.address}.dao-treasury`, deployer.address)
        ]);
        
        // Create proposal
        let block = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'create-proposal', [
                types.ascii("Test Proposal"),
                types.ascii("This is a test proposal for funding"),
                types.uint(500000),
                types.principal(wallet2.address)
            ], wallet1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result, '(ok u1)');
        
        // Verify proposal was created
        let getProposal = chain.callReadOnlyFn('dao-treasury', 'get-proposal', [
            types.uint(1)
        ], deployer.address);
        
        assertEquals(getProposal.result.includes('amount: u500000'), true);
        assertEquals(getProposal.result.includes('executed: false'), true);
    },
});

Clarinet.test({
    name: "Members can vote on proposals",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        const wallet3 = accounts.get('wallet_3')!;
        
        // Setup: Add members and create proposal
        let setup = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'add-member', [
                types.principal(wallet1.address),
                types.uint(100)
            ], deployer.address),
            Tx.contractCall('dao-treasury', 'add-member', [
                types.principal(wallet2.address),
                types.uint(50)
            ], deployer.address),
            Tx.transferSTX(1000000, `${deployer.address}.dao-treasury`, deployer.address)
        ]);
        
        let createProposal = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'create-proposal', [
                types.ascii("Funding Proposal"),
                types.ascii("Fund development work"),
                types.uint(300000),
                types.principal(wallet3.address)
            ], wallet1.address)
        ]);
        
        // Vote on proposal
        let voteBlock = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'vote-on-proposal', [
                types.uint(1),
                types.bool(true)
            ], wallet1.address),
            Tx.contractCall('dao-treasury', 'vote-on-proposal', [
                types.uint(1),
                types.bool(true)
            ], wallet2.address)
        ]);
        
        assertEquals(voteBlock.receipts.length, 2);
        assertEquals(voteBlock.receipts[0].result, '(ok true)');
        assertEquals(voteBlock.receipts[1].result, '(ok true)');
        
        // Check proposal votes
        let getProposal = chain.callReadOnlyFn('dao-treasury', 'get-proposal', [
            types.uint(1)
        ], deployer.address);
        
        assertEquals(getProposal.result.includes('votes-for: u150'), true);
    },
});

Clarinet.test({
    name: "Can execute proposal after voting period",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        const wallet3 = accounts.get('wallet_3')!;
        
        // Setup
        let setup = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'add-member', [
                types.principal(wallet1.address),
                types.uint(100)
            ], deployer.address),
            Tx.transferSTX(1000000, `${deployer.address}.dao-treasury`, deployer.address)
        ]);
        
        let createAndVote = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'create-proposal', [
                types.ascii("Test Proposal"),
                types.ascii("Test description"),
                types.uint(300000),
                types.principal(wallet3.address)
            ], wallet1.address),
            Tx.contractCall('dao-treasury', 'vote-on-proposal', [
                types.uint(1),
                types.bool(true)
            ], wallet1.address)
        ]);
        
        // Mine blocks to pass voting period (1440 blocks)
        chain.mineEmptyBlockUntil(1442);
        
        // Execute proposal
        let executeBlock = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'execute-proposal', [
                types.uint(1)
            ], deployer.address)
        ]);
        
        assertEquals(executeBlock.receipts.length, 1);
        assertEquals(executeBlock.receipts[0].result.includes('(ok u'), true);
    },
});

Clarinet.test({
    name: "Can create and claim streaming payments",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Fund contract
        let fundBlock = chain.mineBlock([
            Tx.transferSTX(2000000, `${deployer.address}.dao-treasury`, deployer.address)
        ]);
        
        // Create stream
        let createStream = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'create-stream', [
                types.principal(wallet1.address),
                types.uint(1000000),
                types.uint(100) // 100 blocks duration
            ], deployer.address)
        ]);
        
        assertEquals(createStream.receipts.length, 1);
        assertEquals(createStream.receipts[0].result, '(ok u1)');
        
        // Mine some blocks to allow vesting
        chain.mineEmptyBlockUntil(50);
        
        // Claim 50% of available amount
        let claimBlock = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'claim-stream-advanced', [
                types.uint(1),
                types.uint(50) // 50% of available
            ], wallet1.address)
        ]);
        
        assertEquals(claimBlock.receipts.length, 1);
        assertEquals(claimBlock.receipts[0].result.includes('(ok {'), true);
        assertEquals(claimBlock.receipts[0].result.includes('vesting-percentage: u49'), true);
    },
});

Clarinet.test({
    name: "Stream claim respects vesting schedule",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Fund and create stream
        let setup = chain.mineBlock([
            Tx.transferSTX(2000000, `${deployer.address}.dao-treasury`, deployer.address),
            Tx.contractCall('dao-treasury', 'create-stream', [
                types.principal(wallet1.address),
                types.uint(1000000),
                types.uint(100)
            ], deployer.address)
        ]);
        
        // Try to claim immediately (should have minimal vesting)
        let earlyClaim = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'claim-stream-advanced', [
                types.uint(1),
                types.uint(100) // 100% of available
            ], wallet1.address)
        ]);
        
        // Mine to 50% completion
        chain.mineEmptyBlockUntil(52);
        
        let midClaim = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'claim-stream-advanced', [
                types.uint(1),
                types.uint(100)
            ], wallet1.address)
        ]);
        
        // Mine to completion
        chain.mineEmptyBlockUntil(102);
        
        let finalClaim = chain.mineBlock([
            Tx.contractCall('dao-treasury', 'claim-stream-advanced', [
                types.uint(1),
                types.uint(100)
            ], wallet1.address)
        ]);
        
        assertEquals(earlyClaim.receipts[0].result.includes('vesting-percentage: u1'), true);
        assertEquals(midClaim.receipts[0].result.includes('vesting-percentage: u51'), true);
        assertEquals(finalClaim.receipts[0].result.includes('vesting-percentage: u100'), true);
    },
});

Clarinet.test({
    name: "Treasury balance tracking works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Check initial balance
        let initialBalance = chain.callReadOnlyFn('dao-treasury', 'get-treasury-balance', [], deployer.address);
        assertEquals(initialBalance.result, 'u0');
        
        // Fund treasury
        let fundBlock = chain.mineBlock([
            Tx.transferSTX(5000000, `${deployer.address}.dao-treasury`, deployer.address)
        ]);
        
        // Check balance after funding
        let afterFunding = chain.callReadOnlyFn('dao-treasury', 'get-treasury-balance', [], deployer.address);
        assertEquals(afterFunding.result, 'u5000000');
    },
});
