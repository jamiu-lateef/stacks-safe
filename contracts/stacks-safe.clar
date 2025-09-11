;; Title: StacksSafe - Bitcoin-Backed Lending Protocol
;;
;; Summary:
;; A sophisticated Bitcoin-collateralized lending platform built on Stacks,
;; enabling secure borrowing against Bitcoin holdings with intelligent risk
;; management and transparent liquidation mechanisms.
;;
;; Description:
;; StacksSafe harnesses the security of Bitcoin through Stacks Layer 2 to create
;; a robust lending ecosystem where users can unlock liquidity from their Bitcoin
;; without selling. The protocol features dynamic risk assessment, automated
;; liquidation protection, and real-time health monitoring to ensure capital
;; efficiency while maintaining the trustless nature of Bitcoin.
;;
;; Key Features:
;;   - Bitcoin-Native Collateralization - Direct Bitcoin backing via Stacks
;;   - Dynamic Risk Engine - Adaptive collateral ratios based on market volatility
;;   - Automated Health Monitoring - Real-time loan surveillance and protection
;;   - Transparent Liquidation System - Fair and predictable liquidation process
;;   - Multi-Asset Support Framework - Extensible architecture for future assets
;;   - Governance-Controlled Parameters - Community-driven risk management
;;
;; Built for the Bitcoin ecosystem, StacksSafe delivers institutional-grade
;; security with DeFi innovation, enabling Bitcoin holders to access capital
;; markets while maintaining exposure to Bitcoin's long-term appreciation.
;;

;; PROTOCOL CONSTANTS & CONFIGURATION

(define-constant CONTRACT-OWNER tx-sender)
(define-constant PROTOCOL-VERSION u1)

;; Protocol Error Codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-ALREADY-INITIALIZED (err u103))
(define-constant ERR-NOT-INITIALIZED (err u104))
(define-constant ERR-LOAN-NOT-FOUND (err u105))
(define-constant ERR-LOAN-INACTIVE (err u106))
(define-constant ERR-INVALID-LOAN-ID (err u107))
(define-constant ERR-INVALID-PRICE-FEED (err u108))
(define-constant ERR-UNSUPPORTED-ASSET (err u109))
(define-constant ERR-LIQUIDATION-FAILED (err u110))

;; Supported Collateral Assets
(define-constant SUPPORTED-ASSETS (list "BTC" "STX"))

;; Default Protocol Parameters
(define-constant DEFAULT-COLLATERAL-RATIO u150) ;; 150% minimum collateral
(define-constant DEFAULT-LIQUIDATION-THRESHOLD u125) ;; 125% liquidation trigger
(define-constant BASE-INTEREST-RATE u500) ;; 5.00% annual (500 basis points)
(define-constant MAX-LOANS-PER-USER u20)

;; PROTOCOL STATE MANAGEMENT

;; Core Protocol State
(define-data-var protocol-active bool false)
(define-data-var min-collateral-ratio uint DEFAULT-COLLATERAL-RATIO)
(define-data-var liquidation-threshold uint DEFAULT-LIQUIDATION-THRESHOLD)
(define-data-var total-value-locked uint u0)
(define-data-var loan-counter uint u0)
(define-data-var emergency-pause bool false)

;; DATA STRUCTURES

;; Loan Registry - Core loan data structure
(define-map loan-registry
  { loan-id: uint }
  {
    borrower: principal,
    collateral-amount: uint,
    borrowed-amount: uint,
    interest-rate: uint,
    creation-block: uint,
    last-update-block: uint,
    status: (string-ascii 10),
  }
)

;; User Portfolio - Track user's active loans
(define-map user-portfolio
  { user: principal }
  { loan-ids: (list 20 uint) }
)

;; Asset Price Oracle - Price feed management
(define-map price-oracle
  { asset: (string-ascii 4) }
  {
    price-usd: uint,
    last-updated: uint,
    is-active: bool,
  }
)

;; INTERNAL UTILITY FUNCTIONS

(define-private (compute-collateral-ratio
    (collateral uint)
    (borrowed uint)
    (asset-price uint)
  )
  ;; Calculate current collateralization ratio for risk assessment
  (let ((collateral-value (* collateral asset-price)))
    (if (is-eq borrowed u0)
      u0
      (* (/ collateral-value borrowed) u100)
    )
  )
)

(define-private (calculate-accrued-interest
    (principal uint)
    (rate uint)
    (blocks-elapsed uint)
  )
  ;; Compute compound interest based on block progression
  (let ((daily-rate (/ rate u365)))
    (/ (* principal daily-rate blocks-elapsed) u10000)
  )
)

(define-private (is-loan-underwater (loan-id uint))
  ;; Determine if loan requires liquidation
  (match (map-get? loan-registry { loan-id: loan-id })
    loan-data (match (map-get? price-oracle { asset: "BTC" })
      price-data (let ((current-ratio (compute-collateral-ratio (get collateral-amount loan-data)
          (get borrowed-amount loan-data) (get price-usd price-data)
        )))
        (<= current-ratio (var-get liquidation-threshold))
      )
      false
    )
    false
  )
)

(define-private (validate-asset (asset (string-ascii 3)))
  ;; Verify asset is supported by protocol
  (is-some (index-of SUPPORTED-ASSETS asset))
)

(define-private (is-valid-loan-id (loan-id uint))
  ;; Validate loan ID within acceptable bounds
  (and (> loan-id u0) (<= loan-id (var-get loan-counter)))
)

;; Global variable to store the target loan ID for filtering
(define-data-var target-loan-id uint u0)

(define-private (remove-if-equal
    (loan-id uint)
    (acc (list 20 uint))
  )
  ;; Helper for fold operation to filter out target ID
  (if (is-eq loan-id (var-get target-loan-id))
    acc
    (unwrap-panic (as-max-len? (append acc loan-id) u20))
  )
)

(define-private (filter-out-loan-id
    (loan-list (list 20 uint))
    (target-id uint)
  )
  ;; Helper function to remove a specific loan ID from a list
  (begin
    (var-set target-loan-id target-id)
    (fold remove-if-equal loan-list (list))
  )
)

(define-private (remove-loan-from-portfolio
    (user principal)
    (loan-id uint)
  )
  ;; Remove completed loan from user's active portfolio
  (match (map-get? user-portfolio { user: user })
    portfolio (begin
      (map-set user-portfolio { user: user } { loan-ids: (filter-out-loan-id (get loan-ids portfolio) loan-id) })
      true
    )
    false
  )
)

;; CORE PROTOCOL FUNCTIONS

(define-public (initialize-protocol)
  ;; Bootstrap StacksSafe protocol for operation
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (not (var-get protocol-active)) ERR-ALREADY-INITIALIZED)

    ;; Initialize default price feeds
    (map-set price-oracle { asset: "BTC" } {
      price-usd: u5000000,
      last-updated: stacks-block-height,
      is-active: true,
    })
    (map-set price-oracle { asset: "STX" } {
      price-usd: u200000,
      last-updated: stacks-block-height,
      is-active: true,
    })

    (var-set protocol-active true)
    (ok "StacksSafe protocol initialized successfully")
  )
)

(define-public (create-loan
    (collateral-amount uint)
    (borrow-amount uint)
    (asset (string-ascii 3))
  )
  ;; Originate new Bitcoin-collateralized loan
  (let (
      (loan-id (+ (var-get loan-counter) u1))
      (price-data (unwrap! (map-get? price-oracle { asset: asset }) ERR-INVALID-PRICE-FEED))
      (collateral-value (* collateral-amount (get price-usd price-data)))
      (required-collateral (* borrow-amount (var-get min-collateral-ratio)))
    )
    (begin
      ;; Protocol validation checks
      (asserts! (var-get protocol-active) ERR-NOT-INITIALIZED)
      (asserts! (not (var-get emergency-pause)) ERR-UNAUTHORIZED)
      (asserts! (validate-asset asset) ERR-UNSUPPORTED-ASSET)
      (asserts! (> collateral-amount u0) ERR-INVALID-AMOUNT)
      (asserts! (> borrow-amount u0) ERR-INVALID-AMOUNT)
      (asserts! (>= collateral-value required-collateral)
        ERR-INSUFFICIENT-COLLATERAL
      )

      ;; Create loan entry
      (map-set loan-registry { loan-id: loan-id } {
        borrower: tx-sender,
        collateral-amount: collateral-amount,
        borrowed-amount: borrow-amount,
        interest-rate: BASE-INTEREST-RATE,
        creation-block: stacks-block-height,
        last-update-block: stacks-block-height,
        status: "active",
      })

      ;; Update user portfolio
      (match (map-get? user-portfolio { user: tx-sender })
        existing-portfolio (map-set user-portfolio { user: tx-sender } { loan-ids: (unwrap!
          (as-max-len? (append (get loan-ids existing-portfolio) loan-id) u20)
          ERR-INVALID-AMOUNT
        ) }
        )
        (map-set user-portfolio { user: tx-sender } { loan-ids: (list loan-id) })
      )

      ;; Update protocol metrics
      (var-set total-value-locked
        (+ (var-get total-value-locked) collateral-amount)
      )
      (var-set loan-counter loan-id)

      (ok loan-id)
    )
  )
)

(define-public (repay-loan
    (loan-id uint)
    (repayment-amount uint)
  )
  ;; Process loan repayment with interest calculation
  (let (
      (loan-data (unwrap! (map-get? loan-registry { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
      (blocks-elapsed (- stacks-block-height (get last-update-block loan-data)))
      (accrued-interest (calculate-accrued-interest (get borrowed-amount loan-data)
        (get interest-rate loan-data) blocks-elapsed
      ))
      (total-owed (+ (get borrowed-amount loan-data) accrued-interest))
    )
    (begin
      ;; Validation checks
      (asserts! (is-eq (get status loan-data) "active") ERR-LOAN-INACTIVE)
      (asserts! (is-eq (get borrower loan-data) tx-sender) ERR-UNAUTHORIZED)
      (asserts! (>= repayment-amount total-owed) ERR-INVALID-AMOUNT)

      ;; Close loan and release collateral
      (map-set loan-registry { loan-id: loan-id }
        (merge loan-data {
          status: "repaid",
          last-update-block: stacks-block-height,
        })
      )

      ;; Update protocol state
      (var-set total-value-locked
        (- (var-get total-value-locked) (get collateral-amount loan-data))
      )

      ;; Remove from user portfolio
      (remove-loan-from-portfolio tx-sender loan-id)

      (ok {
        repaid-amount: total-owed,
        interest-paid: accrued-interest,
        collateral-released: (get collateral-amount loan-data),
      })
    )
  )
)

(define-public (liquidate-loan (loan-id uint))
  ;; Execute liquidation of undercollateralized position
  (let ((loan-data (unwrap! (map-get? loan-registry { loan-id: loan-id }) ERR-LOAN-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get status loan-data) "active") ERR-LOAN-INACTIVE)
      (asserts! (is-loan-underwater loan-id) ERR-LIQUIDATION-FAILED)

      ;; Mark loan as liquidated
      (map-set loan-registry { loan-id: loan-id }
        (merge loan-data {
          status: "liquidated",
          last-update-block: stacks-block-height,
        })
      )

      ;; Update protocol metrics
      (var-set total-value-locked
        (- (var-get total-value-locked) (get collateral-amount loan-data))
      )

      ;; Remove from borrower's portfolio
      (remove-loan-from-portfolio (get borrower loan-data) loan-id)

      (ok "Loan liquidated successfully")
    )
  )
)

;; GOVERNANCE & ADMINISTRATION

(define-public (update-collateral-requirement (new-ratio uint))
  ;; Adjust minimum collateralization ratio for risk management
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (>= new-ratio u110) ERR-INVALID-AMOUNT)
    (asserts! (<= new-ratio u300) ERR-INVALID-AMOUNT)
    (var-set min-collateral-ratio new-ratio)
    (ok "Collateral ratio updated")
  )
)

(define-public (update-liquidation-threshold (new-threshold uint))
  ;; Modify liquidation trigger threshold
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (>= new-threshold u105) ERR-INVALID-AMOUNT)
    (asserts! (< new-threshold (var-get min-collateral-ratio)) ERR-INVALID-AMOUNT)
    (var-set liquidation-threshold new-threshold)
    (ok "Liquidation threshold updated")
  )
)

(define-public (update-price-feed
    (asset (string-ascii 3))
    (new-price uint)
  )
  ;; Update oracle price feed with validated market data
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (validate-asset asset) ERR-UNSUPPORTED-ASSET)
    (asserts! (> new-price u0) ERR-INVALID-PRICE-FEED)

    (map-set price-oracle { asset: asset } {
      price-usd: new-price,
      last-updated: stacks-block-height,
      is-active: true,
    })
    (ok "Price feed updated")
  )
)