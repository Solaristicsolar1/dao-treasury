;; Time-locked DAO Treasury with Streaming Payments
;; A DAO treasury that supports time-locked proposals and streaming payments

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-PROPOSAL-ACTIVE (err u403))
(define-constant ERR-TIMELOCK-ACTIVE (err u405))
(define-constant ERR-STREAM-ACTIVE (err u406))

;; Data Variables
(define-data-var proposal-counter uint u0)
(define-data-var stream-counter uint u0)
(define-data-var voting-period uint u1440) ;; 1440 blocks (~1 day)
(define-data-var timelock-period uint u2880) ;; 2880 blocks (~2 days)
(define-data-var quorum-threshold uint u51) ;; 51% quorum

;; Data Maps
(define-map proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    amount: uint,
    recipient: principal,
    votes-for: uint,
    votes-against: uint,
    created-at: uint,
    executed: bool,
    timelock-end: uint
  }
)

(define-map member-votes
  { proposal-id: uint, voter: principal }
  { vote: bool, weight: uint }
)

(define-map dao-members
  { member: principal }
  { voting-weight: uint, joined-at: uint }
)

(define-map payment-streams
  { stream-id: uint }
  {
    recipient: principal,
    total-amount: uint,
    amount-per-block: uint,
    start-block: uint,
    end-block: uint,
    claimed-amount: uint,
    active: bool
  }
)

;; Public Functions

;; Add DAO member with voting weight
(define-public (add-member (member principal) (weight uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (> weight u0) ERR-INVALID-AMOUNT)
    (map-set dao-members { member: member } 
      { voting-weight: weight, joined-at: block-height })
    (ok true)
  )
)

;; Create a new proposal
(define-public (create-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (amount uint)
  (recipient principal))
  (let ((proposal-id (+ (var-get proposal-counter) u1)))
    (asserts! (is-some (map-get? dao-members { member: tx-sender })) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) amount) ERR-INSUFFICIENT-FUNDS)
    
    (map-set proposals { proposal-id: proposal-id }
      {
        proposer: tx-sender,
        title: title,
        description: description,
        amount: amount,
        recipient: recipient,
        votes-for: u0,
        votes-against: u0,
        created-at: block-height,
        executed: false,
        timelock-end: u0
      })
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

;; Vote on a proposal
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-NOT-FOUND))
    (member-data (unwrap! (map-get? dao-members { member: tx-sender }) ERR-UNAUTHORIZED))
    (voting-weight (get voting-weight member-data))
    (voting-deadline (+ (get created-at proposal) (var-get voting-period)))
  )
    (asserts! (<= block-height voting-deadline) ERR-PROPOSAL-ACTIVE)
    (asserts! (is-none (map-get? member-votes { proposal-id: proposal-id, voter: tx-sender })) ERR-UNAUTHORIZED)
    
    (map-set member-votes { proposal-id: proposal-id, voter: tx-sender }
      { vote: vote-for, weight: voting-weight })
    
    (if vote-for
      (map-set proposals { proposal-id: proposal-id }
        (merge proposal { votes-for: (+ (get votes-for proposal) voting-weight) }))
      (map-set proposals { proposal-id: proposal-id }
        (merge proposal { votes-against: (+ (get votes-against proposal) voting-weight) })))
    
    (ok true)
  )
)

;; Execute approved proposal (starts timelock)
(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-NOT-FOUND))
    (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
    (voting-deadline (+ (get created-at proposal) (var-get voting-period)))
    (timelock-end (+ block-height (var-get timelock-period)))
  )
    (asserts! (> block-height voting-deadline) ERR-PROPOSAL-ACTIVE)
    (asserts! (not (get executed proposal)) ERR-PROPOSAL-ACTIVE)
    (asserts! (>= (* (get votes-for proposal) u100) (* total-votes (var-get quorum-threshold))) ERR-UNAUTHORIZED)
    
    (map-set proposals { proposal-id: proposal-id }
      (merge proposal { timelock-end: timelock-end }))
    (ok timelock-end)
  )
)

;; Finalize proposal after timelock
(define-public (finalize-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-NOT-FOUND)))
    (asserts! (> (get timelock-end proposal) u0) ERR-TIMELOCK-ACTIVE)
    (asserts! (>= block-height (get timelock-end proposal)) ERR-TIMELOCK-ACTIVE)
    (asserts! (not (get executed proposal)) ERR-PROPOSAL-ACTIVE)
    
    (try! (as-contract (stx-transfer? (get amount proposal) tx-sender (get recipient proposal))))
    (map-set proposals { proposal-id: proposal-id }
      (merge proposal { executed: true }))
    (ok true)
  )
)

;; Create streaming payment
(define-public (create-stream 
  (recipient principal)
  (total-amount uint)
  (duration-blocks uint))
  (let (
    (stream-id (+ (var-get stream-counter) u1))
    (amount-per-block (/ total-amount duration-blocks))
    (end-block (+ block-height duration-blocks))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (> total-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> duration-blocks u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) total-amount) ERR-INSUFFICIENT-FUNDS)
    
    (map-set payment-streams { stream-id: stream-id }
      {
        recipient: recipient,
        total-amount: total-amount,
        amount-per-block: amount-per-block,
        start-block: block-height,
        end-block: end-block,
        claimed-amount: u0,
        active: true
      })
    (var-set stream-counter stream-id)
    (ok stream-id)
  )
)

;; Advanced streaming payment claim with vesting schedule and early termination
(define-public (claim-stream-advanced (stream-id uint) (claim-percentage uint))
  (let (
    (stream (unwrap! (map-get? payment-streams { stream-id: stream-id }) ERR-NOT-FOUND))
    (blocks-elapsed (- block-height (get start-block stream)))
    (total-blocks (- (get end-block stream) (get start-block stream)))
    (vested-percentage (if (>= blocks-elapsed total-blocks) u100 (/ (* blocks-elapsed u100) total-blocks)))
    (max-claimable (/ (* (get total-amount stream) vested-percentage) u100))
    (available-amount (- max-claimable (get claimed-amount stream)))
    (claim-amount (if (> claim-percentage u0) 
                    (/ (* available-amount claim-percentage) u100) 
                    available-amount))
  )
    (asserts! (is-eq tx-sender (get recipient stream)) ERR-UNAUTHORIZED)
    (asserts! (get active stream) ERR-STREAM-ACTIVE)
    (asserts! (> available-amount u0) ERR-INSUFFICIENT-FUNDS)
    (asserts! (<= claim-percentage u100) ERR-INVALID-AMOUNT)
    (asserts! (> claim-amount u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer the claimed amount
    (try! (as-contract (stx-transfer? claim-amount tx-sender (get recipient stream))))
    
    ;; Update stream state
    (let ((new-claimed-amount (+ (get claimed-amount stream) claim-amount)))
      (map-set payment-streams { stream-id: stream-id }
        (merge stream { 
          claimed-amount: new-claimed-amount,
          active: (< new-claimed-amount (get total-amount stream))
        }))
      
      ;; Return detailed claim information
      (ok {
        claimed-amount: claim-amount,
        total-claimed: new-claimed-amount,
        remaining-amount: (- (get total-amount stream) new-claimed-amount),
        vesting-percentage: vested-percentage,
        stream-completed: (>= new-claimed-amount (get total-amount stream))
      })
    )
  )
)

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-stream (stream-id uint))
  (map-get? payment-streams { stream-id: stream-id })
)

(define-read-only (get-treasury-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-member (member principal))
  (map-get? dao-members { member: member })
)
