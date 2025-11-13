(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-BUSINESS-NOT-FOUND (err u404))
(define-constant ERR-INSUFFICIENT-BALANCE (err u403))
(define-constant ERR-TRANSFER-RESTRICTED (err u405))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-ALREADY-EXISTS (err u409))

(define-constant ERR-PROPOSAL-NOT-FOUND (err u410))
(define-constant ERR-ALREADY-VOTED (err u411))
(define-constant ERR-VOTING-ENDED (err u412))
(define-constant ERR-PROPOSAL-NOT-PASSED (err u413))
(define-constant ERR-MIN-SHARES-REQUIRED (err u414))

(define-constant ERR-VESTING-NOT-FOUND (err u415))
(define-constant ERR-NO-VESTED-SHARES (err u416))
(define-constant ERR-VESTING-EXISTS (err u417))

(define-data-var next-vesting-id uint u0)

(define-data-var next-proposal-id uint u0)

(define-data-var contract-owner principal tx-sender)
(define-data-var next-business-id uint u0)

(define-map businesses
  { business-id: uint }
  {
    name: (string-ascii 50),
    owner: principal,
    total-shares: uint,
    valuation: uint,
    dividend-pool: uint,
    created-at: uint,
    active: bool
  }
)

(define-map equity-tokens
  { business-id: uint, holder: principal }
  { shares: uint }
)

(define-map business-owners
  { owner: principal, business-id: uint }
  { authorized: bool }
)

(define-map transfer-restrictions
  { business-id: uint }
  { restricted: bool, min-holding-period: uint }
)

(define-map investment-history
  { business-id: uint, investor: principal }
  { invested-at: uint, total-invested: uint }
)

(define-public (register-business (name (string-ascii 50)) (total-shares uint) (valuation uint))
  (let ((business-id (+ (var-get next-business-id) u1)))
    (asserts! (> total-shares u0) ERR-INVALID-AMOUNT)
    (asserts! (> valuation u0) ERR-INVALID-AMOUNT)
    (map-set businesses
      { business-id: business-id }
      {
        name: name,
        owner: tx-sender,
        total-shares: total-shares,
        valuation: valuation,
        dividend-pool: u0,
        created-at: stacks-block-height,
        active: true
      }
    )
    (map-set business-owners
      { owner: tx-sender, business-id: business-id }
      { authorized: true }
    )
    (map-set equity-tokens
      { business-id: business-id, holder: tx-sender }
      { shares: total-shares }
    )
    (map-set transfer-restrictions
      { business-id: business-id }
      { restricted: false, min-holding-period: u144 }
    )
    (var-set next-business-id business-id)
    (ok business-id)
  )
)

(define-public (invest (business-id uint) (shares uint))
  (let (
    (business (unwrap! (map-get? businesses { business-id: business-id }) ERR-BUSINESS-NOT-FOUND))
    (business-owner (get owner business))
    (share-price (/ (get valuation business) (get total-shares business)))
    (investment-cost (* shares share-price))
    (current-owner-shares (default-to u0 (get shares (map-get? equity-tokens { business-id: business-id, holder: business-owner }))))
  )
    (asserts! (get active business) ERR-BUSINESS-NOT-FOUND)
    (asserts! (> shares u0) ERR-INVALID-AMOUNT)
    (asserts! (>= current-owner-shares shares) ERR-INSUFFICIENT-BALANCE)
    (try! (stx-transfer? investment-cost tx-sender business-owner))
    (map-set equity-tokens
      { business-id: business-id, holder: business-owner }
      { shares: (- current-owner-shares shares) }
    )
    (map-set equity-tokens
      { business-id: business-id, holder: tx-sender }
      { shares: (+ (default-to u0 (get shares (map-get? equity-tokens { business-id: business-id, holder: tx-sender }))) shares) }
    )
    (map-set investment-history
      { business-id: business-id, investor: tx-sender }
      { invested-at: stacks-block-height, total-invested: (+ (default-to u0 (get total-invested (map-get? investment-history { business-id: business-id, investor: tx-sender }))) investment-cost) }
    )
    (ok true)
  )
)

(define-public (transfer-shares (business-id uint) (recipient principal) (shares uint))
  (let (
    (business (unwrap! (map-get? businesses { business-id: business-id }) ERR-BUSINESS-NOT-FOUND))
    (restrictions (unwrap! (map-get? transfer-restrictions { business-id: business-id }) ERR-BUSINESS-NOT-FOUND))
    (sender-shares (default-to u0 (get shares (map-get? equity-tokens { business-id: business-id, holder: tx-sender }))))
    (investment-time (default-to u0 (get invested-at (map-get? investment-history { business-id: business-id, investor: tx-sender }))))
  )
    (asserts! (get active business) ERR-BUSINESS-NOT-FOUND)
    (asserts! (> shares u0) ERR-INVALID-AMOUNT)
    (asserts! (>= sender-shares shares) ERR-INSUFFICIENT-BALANCE)
    (asserts! (or (not (get restricted restrictions)) (>= (- stacks-block-height investment-time) (get min-holding-period restrictions))) ERR-TRANSFER-RESTRICTED)
    (map-set equity-tokens
      { business-id: business-id, holder: tx-sender }
      { shares: (- sender-shares shares) }
    )
    (map-set equity-tokens
      { business-id: business-id, holder: recipient }
      { shares: (+ (default-to u0 (get shares (map-get? equity-tokens { business-id: business-id, holder: recipient }))) shares) }
    )
    (ok true)
  )
)

(define-public (distribute-dividends (business-id uint))
  (let (
    (business (unwrap! (map-get? businesses { business-id: business-id }) ERR-BUSINESS-NOT-FOUND))
    (is-owner (unwrap! (map-get? business-owners { owner: tx-sender, business-id: business-id }) ERR-NOT-AUTHORIZED))
  )
    (asserts! (get authorized is-owner) ERR-NOT-AUTHORIZED)
    (asserts! (get active business) ERR-BUSINESS-NOT-FOUND)
    (asserts! (> (get dividend-pool business) u0) ERR-INVALID-AMOUNT)
    (map-set businesses
      { business-id: business-id }
      (merge business { dividend-pool: u0 })
    )
    (ok true)
  )
)

(define-public (add-to-dividend-pool (business-id uint) (amount uint))
  (let (
    (business (unwrap! (map-get? businesses { business-id: business-id }) ERR-BUSINESS-NOT-FOUND))
    (is-owner (unwrap! (map-get? business-owners { owner: tx-sender, business-id: business-id }) ERR-NOT-AUTHORIZED))
  )
    (asserts! (get authorized is-owner) ERR-NOT-AUTHORIZED)
    (asserts! (get active business) ERR-BUSINESS-NOT-FOUND)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set businesses
      { business-id: business-id }
      (merge business { dividend-pool: (+ (get dividend-pool business) amount) })
    )
    (ok true)
  )
)

(define-public (set-transfer-restrictions (business-id uint) (restricted bool) (min-period uint))
  (let (
    (business (unwrap! (map-get? businesses { business-id: business-id }) ERR-BUSINESS-NOT-FOUND))
    (is-owner (unwrap! (map-get? business-owners { owner: tx-sender, business-id: business-id }) ERR-NOT-AUTHORIZED))
  )
    (asserts! (get authorized is-owner) ERR-NOT-AUTHORIZED)
    (map-set transfer-restrictions
      { business-id: business-id }
      { restricted: restricted, min-holding-period: min-period }
    )
    (ok true)
  )
)

(define-read-only (get-business (business-id uint))
  (map-get? businesses { business-id: business-id })
)

(define-read-only (get-shares (business-id uint) (holder principal))
  (default-to u0 (get shares (map-get? equity-tokens { business-id: business-id, holder: holder })))
)

(define-read-only (get-investment-history (business-id uint) (investor principal))
  (map-get? investment-history { business-id: business-id, investor: investor })
)

(define-read-only (get-transfer-restrictions (business-id uint))
  (map-get? transfer-restrictions { business-id: business-id })
)

(define-read-only (calculate-dividend-share (business-id uint) (holder principal))
  (let (
    (business (unwrap! (map-get? businesses { business-id: business-id }) (err u404)))
    (holder-shares (get-shares business-id holder))
    (total-shares (get total-shares business))
    (dividend-pool (get dividend-pool business))
  )
    (if (> total-shares u0)
      (ok (/ (* dividend-pool holder-shares) total-shares))
      (err u400)
    )
  )
)

(define-read-only (get-total-businesses)
  (var-get next-business-id)
)


(define-map proposals
  { proposal-id: uint }
  {
    business-id: uint,
    proposer: principal,
    description: (string-ascii 200),
    votes-for: uint,
    votes-against: uint,
    voting-deadline: uint,
    executed: bool,
    min-approval-rate: uint
  }
)

(define-map shareholder-votes
  { proposal-id: uint, voter: principal }
  { vote-weight: uint, vote-for: bool }
)

(define-public (create-proposal 
  (business-id uint) 
  (description (string-ascii 200)) 
  (voting-duration uint) 
  (min-approval-rate uint))
  (let (
    (proposal-id (+ (var-get next-proposal-id) u1))
    (voter-shares (get-shares business-id tx-sender))
  )
    (asserts! (> voter-shares u0) ERR-MIN-SHARES-REQUIRED)
    (asserts! (is-some (map-get? businesses { business-id: business-id })) ERR-BUSINESS-NOT-FOUND)
    (map-set proposals
      { proposal-id: proposal-id }
      {
        business-id: business-id,
        proposer: tx-sender,
        description: description,
        votes-for: u0,
        votes-against: u0,
        voting-deadline: (+ stacks-block-height voting-duration),
        executed: false,
        min-approval-rate: min-approval-rate
      }
    )
    (var-set next-proposal-id proposal-id)
    (ok proposal-id)
  )
)

(define-public (cast-vote (proposal-id uint) (vote-for bool))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
    (voter-shares (get-shares (get business-id proposal) tx-sender))
    (existing-vote (map-get? shareholder-votes { proposal-id: proposal-id, voter: tx-sender }))
  )
    (asserts! (> voter-shares u0) ERR-MIN-SHARES-REQUIRED)
    (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
    (asserts! (< stacks-block-height (get voting-deadline proposal)) ERR-VOTING-ENDED)
    (map-set shareholder-votes
      { proposal-id: proposal-id, voter: tx-sender }
      { vote-weight: voter-shares, vote-for: vote-for }
    )
    (map-set proposals
      { proposal-id: proposal-id }
      (if vote-for
        (merge proposal { votes-for: (+ (get votes-for proposal) voter-shares) })
        (merge proposal { votes-against: (+ (get votes-against proposal) voter-shares) })
      )
    )
    (ok true)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-voter-ballot (proposal-id uint) (voter principal))
  (map-get? shareholder-votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-proposal-result (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal
      (let (
        (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
        (approval-rate (if (> total-votes u0) (/ (* (get votes-for proposal) u100) total-votes) u0))
      )
        (ok { 
          passed: (>= approval-rate (get min-approval-rate proposal)),
          approval-rate: approval-rate,
          votes-for: (get votes-for proposal),
          votes-against: (get votes-against proposal)
        })
      )
    ERR-PROPOSAL-NOT-FOUND
  )
)

(define-map vesting-schedules
  { vesting-id: uint }
  {
    business-id: uint,
    beneficiary: principal,
    total-shares: uint,
    claimed-shares: uint,
    start-block: uint,
    cliff-duration: uint,
    vesting-duration: uint,
    revoked: bool
  }
)

(define-map beneficiary-vesting
  { business-id: uint, beneficiary: principal }
  { vesting-id: uint }
)

(define-public (create-vesting-schedule
  (business-id uint)
  (beneficiary principal)
  (total-shares uint)
  (cliff-duration uint)
  (vesting-duration uint))
  (let (
    (business (unwrap! (map-get? businesses { business-id: business-id }) ERR-BUSINESS-NOT-FOUND))
    (is-owner (unwrap! (map-get? business-owners { owner: tx-sender, business-id: business-id }) ERR-NOT-AUTHORIZED))
    (owner-shares (get-shares business-id tx-sender))
    (vesting-id (+ (var-get next-vesting-id) u1))
    (existing-vesting (map-get? beneficiary-vesting { business-id: business-id, beneficiary: beneficiary }))
  )
    (asserts! (get authorized is-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> total-shares u0) ERR-INVALID-AMOUNT)
    (asserts! (>= owner-shares total-shares) ERR-INSUFFICIENT-BALANCE)
    (asserts! (< cliff-duration vesting-duration) ERR-INVALID-AMOUNT)
    (asserts! (is-none existing-vesting) ERR-VESTING-EXISTS)
    (map-set vesting-schedules
      { vesting-id: vesting-id }
      {
        business-id: business-id,
        beneficiary: beneficiary,
        total-shares: total-shares,
        claimed-shares: u0,
        start-block: stacks-block-height,
        cliff-duration: cliff-duration,
        vesting-duration: vesting-duration,
        revoked: false
      }
    )
    (map-set beneficiary-vesting
      { business-id: business-id, beneficiary: beneficiary }
      { vesting-id: vesting-id }
    )
    (map-set equity-tokens
      { business-id: business-id, holder: tx-sender }
      { shares: (- owner-shares total-shares) }
    )
    (var-set next-vesting-id vesting-id)
    (ok vesting-id)
  )
)

(define-public (claim-vested-shares (vesting-id uint))
  (let (
    (schedule (unwrap! (map-get? vesting-schedules { vesting-id: vesting-id }) ERR-VESTING-NOT-FOUND))
    (vested-amount (unwrap! (get-vested-amount vesting-id) ERR-VESTING-NOT-FOUND))
    (claimable-shares (- vested-amount (get claimed-shares schedule)))
  )
    (asserts! (is-eq tx-sender (get beneficiary schedule)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get revoked schedule)) ERR-TRANSFER-RESTRICTED)
    (asserts! (> claimable-shares u0) ERR-NO-VESTED-SHARES)
    (map-set vesting-schedules
      { vesting-id: vesting-id }
      (merge schedule { claimed-shares: vested-amount })
    )
    (map-set equity-tokens
      { business-id: (get business-id schedule), holder: tx-sender }
      { shares: (+ (get-shares (get business-id schedule) tx-sender) claimable-shares) }
    )
    (ok claimable-shares)
  )
)

(define-read-only (get-vested-amount (vesting-id uint))
  (match (map-get? vesting-schedules { vesting-id: vesting-id })
    schedule
      (let (
        (elapsed-blocks (- stacks-block-height (get start-block schedule)))
        (cliff-duration (get cliff-duration schedule))
        (vesting-duration (get vesting-duration schedule))
        (total-shares (get total-shares schedule))
      )
        (if (get revoked schedule)
          (ok (get claimed-shares schedule))
          (if (< elapsed-blocks cliff-duration)
            (ok u0)
            (if (>= elapsed-blocks vesting-duration)
              (ok total-shares)
              (ok (/ (* total-shares elapsed-blocks) vesting-duration))
            )
          )
        )
      )
    (err u404)
  )
)

(define-read-only (get-vesting-schedule (vesting-id uint))
  (map-get? vesting-schedules { vesting-id: vesting-id })
)