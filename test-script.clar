;; Manual test script for DAO Treasury contract
;; Run this in clarinet console

;; Test 1: Add DAO member
(contract-call? .dao-treasury add-member 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5 u100)

;; Test 2: Check member was added
(contract-call? .dao-treasury get-member 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)

;; Test 3: Fund the contract
(stx-transfer? u1000000 .dao-treasury)

;; Test 4: Check treasury balance
(contract-call? .dao-treasury get-treasury-balance)

;; Test 5: Create proposal (as member)
::set_tx_sender ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5
(contract-call? .dao-treasury create-proposal "Test Proposal" "Testing the DAO" u500000 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)

;; Test 6: Vote on proposal
(contract-call? .dao-treasury vote-on-proposal u1 true)

;; Test 7: Check proposal details
(contract-call? .dao-treasury get-proposal u1)

;; Test 8: Create streaming payment
::set_tx_sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
(contract-call? .dao-treasury create-stream 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5 u1000000 u100)

;; Test 9: Check stream details
(contract-call? .dao-treasury get-stream u1)

;; Test 10: Advance blocks and claim stream
::advance_chain_tip 50
::set_tx_sender ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5
(contract-call? .dao-treasury claim-stream-advanced u1 u50)
