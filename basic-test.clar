;; Basic automated test for DAO Treasury
;; This will test core functionality

;; Test 1: Add member (should succeed)
(contract-call? .dao-treasury add-member 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5 u100)

;; Test 2: Fund treasury
(stx-transfer? u1000000 .dao-treasury)

;; Test 3: Check treasury balance
(contract-call? .dao-treasury get-treasury-balance)

;; Test 4: Try to add member as non-owner (should fail)
::set_tx_sender ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5
(contract-call? .dao-treasury add-member 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG u50)

;; Reset to deployer
::set_tx_sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM

;; Test 5: Create proposal as member
::set_tx_sender ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5
(contract-call? .dao-treasury create-proposal "Test Proposal" "Testing DAO functionality" u500000 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
