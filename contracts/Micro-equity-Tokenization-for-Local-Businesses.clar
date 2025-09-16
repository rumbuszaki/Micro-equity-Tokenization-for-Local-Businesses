(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-BUSINESS-NOT-FOUND (err u404))
(define-constant ERR-INSUFFICIENT-BALANCE (err u403))
(define-constant ERR-TRANSFER-RESTRICTED (err u405))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-ALREADY-EXISTS (err u409))

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
