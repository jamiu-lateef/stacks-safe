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