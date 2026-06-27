# RiskEngine — Architecture Specification

> **Status:** ✅ V3 complete and tested.
>
> **Protocol phase:** [LENDING_PROTOCOL.md](./LENDING_PROTOCOL.md) Phase 4 — Risk Engine.
>
> **Scope:** Current V3 implementation (single-asset ETH). Per-asset portfolio risk is planned in [MULTI_ASSET_LENDING.md](./MULTI_ASSET_LENDING.md) Phase 6.
>
> **Last synchronized:** June 2026 · see [Document Maintenance](./RISK_ENGINE.md#11-document-maintenance) in this file and [LENDING_PROTOCOL.md §13](./LENDING_PROTOCOL.md#13-document-maintenance).

---

## 1. Executive Summary

`RiskEngine.sol` serves as the primary risk management and validation layer for the protocol. It is isolated from core accounting logic to enforce collateral safety, liquidation thresholds, protocol caps, and emergency controls.

By decoupling risk calculations from core execution, `Lending.sol` remains strictly focused on user asset accounting (deposits, withdrawals, borrowing, and repayments), while the `RiskEngine` independently governs protocol solvency and system limits.

> **Liquidation parameters:** `closeFactor` and `liquidationBonus` were moved to `LiquidationEngine.sol`. See [LIQUIDATION_ENGINE.md](./LIQUIDATION_ENGINE.md).

---

## 2. Architecture Overview

### 2.1 Protocol Topology

Lending.sol (User Accounting)
↓
RiskEngine.sol (Risk Validation)
↓
PriceOracle.sol (Asset Valuation)

### 2.2 System Responsibilities


| Contract / Role | Primary Responsibility |
| :--- | :--- |
| **Lending** | Executes user interactions, state updates, and ledger accounting. |
| **RiskEngine** | Validates state transitions against risk parameters and caps. |
| **PriceOracle** | Provides real-time asset pricing and exchange rates. |
| **LiquidationEngine** | Close factor, liquidation bonus, seizure math, preview (not in RiskEngine). |
| **Timelock** | Enforces governance-mandated execution delays on critical functions. |

---

## 3. Core Responsibilities

The `RiskEngine` autonomously evaluates and enforces the following protocol invariants:

* **Solvency Calculations**: Computes real-time account health factors.
* **Transaction Validation**: Authorises or reverts borrow and withdrawal requests.
* **Liquidation Eligibility**: Evaluates whether health factor permits liquidation (`isLiquidatable`). Close factor and bonus live in `LiquidationEngine`.
* **Supply & Borrow Constraints**: Restricts global TVL and debt exposure via protocol-wide caps.
* **Emergency Management**: Provides hooks for instant circuit-breaking by designated Guardians.

---

## 4. Risk Configuration Parameters


| Parameter | Type | Purpose |
| :--- | :--- | :--- |
| `maxBorrowRatio` | Percentage | Maximum borrowing capacity against deposited collateral (default 50%). |
| `liquidationThreshold` | Percentage | Collateral haircut weight in health factor numerator (default 75%). |
| `minHealthFactor` | Scaled Uint | Minimum HF to borrow/withdraw safely; below this = liquidatable (default 1e18). |
| `supplyCap` | Asset Amount | Global ceiling for aggregated ETH deposits. |
| `borrowCap` | Asset Amount | Global ceiling for aggregated ETH debt. |

**Not in RiskEngine (see [LIQUIDATION_ENGINE.md](./LIQUIDATION_ENGINE.md)):** `closeFactor`, `liquidationBonus`.

---

## 5. Account Health & Solvency Framework

### 5.1 Mathematical Formula
Account solvency is determined by the relation of risk-adjusted collateral value to total outstanding debt value:

$$\text{Health Factor (HF)} = \frac{\text{Collateral Value (USD)} \times \text{Liquidation Threshold}}{\text{Total Debt Value (USD)}}$$

### 5.2 Smart Contract Implementation
```solidity
// High-precision internal calculation
collateralAdjusted = (collateralUsd * liquidationThreshold) / LIQUIDATION_PRECISION;
healthFactor = (collateralAdjusted * PRECISION) / debtUsd;
```

### 5.3 Health Factor Evaluation Matrix


| Threshold | Account Status | Liquidation Condition | Action Allowed |
| :--- | :--- | :--- | :--- |
| **HF > 1.0** | Solvent | Immune | All regular interactions approved. |
| **HF = 1.0** | Critical | At Risk | Account is eligible for immediate liquidation. |
| **HF < 1.0** | Insolvent | Eligible | Borrowing/Withdrawals blocked; liquidators may seize assets. |

---

## 6. System Validation Workflows

### 6.1 Borrow Validation Flow
1. User submits a borrow request to `Lending.sol`.
2. `PriceOracle` translates asset values into standard USD denominations.
3. `Lending` requests authorization via `RiskEngine.canBorrow()`.
4. `RiskEngine` verifies if the post-interaction state satisfies:  
   $$\text{debtUsd} \le \text{maxBorrow}(\text{collateralUsd})$$
5. Transaction executes or reverts based on validation output.

### 6.2 Withdrawal Validation Flow
1. User requests a partial or full collateral withdrawal.
2. `RiskEngine` calculates hypothetical remaining collateral value.
3. System verifies that the remaining collateral securely covers any existing debt.
4. Outflow is blocked if the post-withdrawal state degrades the health factor below `minHealthFactor`.

---

## 7. Liquidation Integration

Liquidation is programmatically activated when an account's health factor drops below `minHealthFactor` (1.0). **RiskEngine** exposes `isLiquidatable(healthFactor)`. **LiquidationEngine** owns close factor, bonus, and seizure math.

### 7.1 Eligibility (RiskEngine)

```text
isLiquidatable(HF) = HF < minHealthFactor
```

### 7.2 Execution Policy (LiquidationEngine)

See [LIQUIDATION_ENGINE.md](./LIQUIDATION_ENGINE.md):

$$\text{Max Repayment} = \frac{\text{Debt} \times \text{closeFactor}}{100}$$

$$\text{Seized Collateral} = \text{repayAmount} \times \left(1 + \frac{\text{liquidationBonus}}{100}\right)$$

**Integration status:** Module phases 1–3 complete; `Lending` constructor wiring and E2E tests in progress — [LENDING_PROTOCOL.md §3.7](./LENDING_PROTOCOL.md#37-liquidationengine).

---

## 8. Protocol Limits & Emergency Controls

### 8.1 Global Caps
* **Supply Cap**: Restricts aggregate collateral exposure. This mitigates protocol risk against oversized single-entity deposits and limits liquidity concentration.
* **Borrow Cap**: Limits maximum systemic debt allocation to prevent total liquidity exhaustion and catastrophic insolvency events.

### 8.2 Circuit Breaker System (Guardian Module)
The protocol separates long-term governance from immediate operational security via a dedicated **Guardian** role.


| Emergency Function | Operational Target | Target Mitigations |
| :--- | :--- | :--- |
| `pauseBorrowing()` | Freezes new debt origination | Exploits, highly volatile market spikes. |
| `pauseLiquidation()` | Freezes liquidation actions | Oracle failures, flash-crash anomalies. |
| `pauseDepositing()` | Freezes incoming capital | Smart contract vulnerabilities. |

### 8.3 Privilege Separation Architecture


* **Guardians Can**: Instantly pause or unpause specific actions during market stress.
* **Guardians Cannot**: Modify risk parameters, alter supply/borrow caps, or reassign ownership.

---

## 9. Developer Reference & Technical Specifications

### 9.1 Internal Validation Architecture
Core validation logic is centralised inside gas-optimized internal functions to ensure consistent enforcement across entry points:
* `_isDebtSafe()`: Validates final account positions post-state change.
* `_maxBorrow()`: Mathematical helper mapping collateral assets to borrowing ceilings.

### 9.2 Critical Events
The engine emits explicit logs to support off-chain monitoring, indexing engines, and frontend updates:
* `MaxBorrowUpdated(uint256 newRatio)`
* `BorrowPaused(bool status)`
* `SupplyCapUpdated(uint256 newCap)`

### 9.3 Known Security Assumptions & Boundaries (V3)
* **Price Feed Trust**: System assumes connected oracle feeds are accurate and manipulation-resistant.
* **Asset Homogeneity**: Architected explicitly for single-collateral (ETH) and single-debt (ETH) asset configurations.
* **Honest Actors**: Assumes the designated Guardian operates without malicious intent.

### 9.4 Explicit System Limitations
* Lacks isolated margin or multi-collateral capabilities.
* Does not feature dynamic, utilisation-based interest rate models.
* No internal bad debt socialisation or auction mechanisms implemented.

---

## 10. Future Upgrade Roadmap (V4+)

Aligned with [LENDING_PROTOCOL.md §5](./LENDING_PROTOCOL.md#5-detailed-development-roadmap) and [MULTI_ASSET_LENDING.md](./MULTI_ASSET_LENDING.md):

| Upgrade | Master Phase | Blueprint |
| :--- | :--- | :--- |
| Per-asset LTV / threshold / caps | Phase 7+ | MULTI_ASSET_LENDING Phase 6 |
| Portfolio health aggregation | Phase 7+ | MULTI_ASSET_LENDING Phase 6 |
| Isolation Mode | Phase 11 | MULTI_ASSET_LENDING §5.11 |
| E-Mode | Phase 12 | MULTI_ASSET_LENDING §5.12 |
| Dynamic interest rates | Phase 10 | MULTI_ASSET_LENDING Phase 8 |
| Liquidation auctions / dynamic bonus | Phase 8+ | LIQUIDATION_ENGINE Phase 5+ |

---

## 11. Document Maintenance

This specification must stay aligned with [LENDING_PROTOCOL.md](./LENDING_PROTOCOL.md) — the master architecture document.

| When | Update |
| :--- | :--- |
| RiskEngine code changes | Sections 4–9 and parameter tables |
| Liquidation params change | Section 7 + [LIQUIDATION_ENGINE.md](./LIQUIDATION_ENGINE.md) (not this file) |
| Multi-asset risk ships | Add V4 section or link to MULTI_ASSET_LENDING Phase 6 |
| Phase 4 marked complete/in progress | Status header at top of this file |

**Status legend:** ✅ complete · 🟡 in progress · ⬜ planned — consistent across all `docs/` files.