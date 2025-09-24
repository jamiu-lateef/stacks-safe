# 📘 StacksSafe – Bitcoin-Backed Lending Protocol

**StacksSafe** is a **Bitcoin-collateralized lending protocol** built on **Stacks Layer 2**, enabling users to unlock liquidity without selling their Bitcoin. The protocol provides a secure, transparent, and governance-driven lending framework, ensuring capital efficiency while leveraging Bitcoin’s security guarantees.

---

## 🚀 System Overview

StacksSafe allows Bitcoin holders to deposit BTC (and supported assets such as STX) as collateral and borrow stable or synthetic assets against it.

Key mechanisms include:

* **Collateralization Engine** – ensures all loans maintain minimum over-collateralization.
* **Dynamic Risk Management** – protocol parameters (ratios, thresholds, fees) can be tuned via governance.
* **Automated Liquidation System** – undercollateralized positions are transparently liquidated to preserve solvency.
* **Interest Accrual & Repayment** – borrowed amounts accrue interest over block intervals, repaid by borrowers to release collateral.
* **Oracle Integration** – price feeds ensure real-time valuation of supported assets.

---

## 🏗️ Contract Architecture

The protocol is implemented as a **single Clarity contract** with modular state maps and data variables.

### Core Components

1. **Protocol State**

   * Tracks activation status, collateral ratios, liquidation thresholds, emergency pause, and global TVL metrics.

2. **Loan Registry**

   * Stores all active and historical loan data (`loan-registry`).
   * Each loan contains borrower address, collateral, borrowed amount, interest rate, creation/update blocks, and status.

3. **User Portfolio**

   * Maps users to their active loan IDs for quick retrieval.

4. **Price Oracle**

   * Tracks current USD-denominated prices for supported assets.
   * Updated by governance/owner, enabling accurate collateral valuation.

---

## 🔄 Data Flow

Below is a simplified flow of interactions within StacksSafe:

### 1. Loan Origination (`create-loan`)

* User deposits collateral in BTC/STX.
* Oracle price is fetched → collateral ratio validated.
* Loan entry created in registry + portfolio updated.
* Protocol TVL incremented.

### 2. Loan Health Monitoring

* Health metrics computed via `get-loan-health`.
* If ratio drops below liquidation threshold → loan eligible for liquidation.

### 3. Repayment (`repay-loan`)

* Borrower repays principal + accrued interest.
* Loan marked `repaid`, collateral released.
* TVL updated and loan removed from borrower portfolio.

### 4. Liquidation (`liquidate-loan`)

* Any actor can trigger liquidation if collateral ratio falls below threshold.
* Loan marked `liquidated`, collateral seized.
* Protocol TVL reduced.

### 5. Governance & Administration

* Owner can update collateral ratio, liquidation threshold, oracle feeds, or trigger an emergency pause.

---

## ⚙️ Key Protocol Parameters

| Parameter                 | Default Value | Description                                   |
| ------------------------- | ------------- | --------------------------------------------- |
| **Collateral Ratio**      | 150%          | Minimum required ratio to open a loan         |
| **Liquidation Threshold** | 125%          | Loan is liquidated when ratio falls below     |
| **Interest Rate**         | 5% APR        | Applied to borrowed amount, accrued per block |
| **Max Loans per User**    | 20            | Limit of concurrent loans per user            |

---

## 📑 Contract Functions

### 🔹 Public Entry Points

* `initialize-protocol` – Bootstraps contract, sets initial oracles.
* `create-loan` – Opens a new collateralized loan.
* `repay-loan` – Repays debt + accrued interest, releases collateral.
* `liquidate-loan` – Liquidates undercollateralized loans.
* `update-collateral-requirement` – Adjusts collateral ratio.
* `update-liquidation-threshold` – Adjusts liquidation trigger.
* `update-price-feed` – Updates oracle values.
* `emergency-pause-protocol` – Pauses/resumes protocol activity.

### 🔹 Read-Only Queries

* `get-loan-info` – Fetch loan details.
* `get-user-portfolio` – Fetch all loans tied to a user.
* `get-protocol-metrics` – Returns TVL, active loans, thresholds, protocol status.
* `get-asset-price` – Fetch current oracle price.
* `get-loan-health` – Returns collateral ratio, accrued interest, debt, and health status.
* `get-supported-assets` – Lists supported collateral assets.

---

## 🛡️ Security & Risk Management

* **Overcollateralization** – Ensures borrowed amounts are always secured.
* **Emergency Pause** – Admin can pause protocol during abnormal conditions.
* **Transparent Liquidations** – Liquidation rules are deterministic and on-chain.
* **Oracle Validation** – Strict checks ensure only valid assets and prices are accepted.

---

## 📚 Development Notes

* Written in **Clarity**, optimized for composability with other Stacks-based DeFi protocols.
* Modular state maps allow extension to support new collateral types.
* Loan IDs increment sequentially for easy indexing.
* Gas efficiency prioritized via `fold` and `unwrap` operations for list/portfolio updates.

---

## 📊 Example Architecture Diagram

```
 +---------------------+       +--------------------+
 |   User Portfolio    | <---> |   Loan Registry    |
 +---------------------+       +--------------------+
           ^                          ^
           |                          |
           v                          v
 +---------------------+       +--------------------+
 |  Collateral Engine  | <---> |  Price Oracle Feed |
 +---------------------+       +--------------------+
           |
           v
 +---------------------+
 | Governance & Admin  |
 +---------------------+
```

---

## ✅ Conclusion

**StacksSafe** delivers an **institutional-grade lending protocol** for the Bitcoin economy, merging **Bitcoin-native security** with **DeFi flexibility** on Stacks. It provides a transparent, extensible, and governance-driven platform for unlocking liquidity without sacrificing long-term Bitcoin exposure.
