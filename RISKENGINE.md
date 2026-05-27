# RiskEngine V3

## 1. Executive Summary

`RiskEngine.sol` serves as the primary risk management and validation layer for the protocol. It is isolated from core accounting logic to enforce collateral safety, liquidation thresholds, protocol caps, and emergency controls.

By decoupling risk calculations from core execution, `Lending.sol` remains strictly focused on user asset accounting (deposits, withdrawals, borrowing, and repayments), while the `RiskEngine` independently governs protocol solvency and system limits.

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
| **Timelock** | Enforces governance-mandated execution delays on critical functions. |

---

## 3. Core Responsibilities

The `RiskEngine` autonomously evaluates and enforces the following protocol invariants:

* **Solvency Calculations**: Computes real-time account health factors.
* **Transaction Validation**: Authorises or reverts borrow and withdrawal requests.
* **Liquidation Enforcement**: Evaluates liquidation eligibility, caps, and liquidator bonuses.
* **Supply & Borrow Constraints**: Restricts global TVL and debt exposure via protocol-wide caps.
* **Emergency Management**: Provides hooks for instant circuit-breaking by designated Guardians.

---

## 4. Risk Configuration Parameters


| Parameter | Type | Purpose |
| :--- | :--- | :--- |
| `maxBorrowRatio` | Percentage | Maximum borrowing capacity against deposited collateral. |
| `liquidationThreshold` | Percentage | The collateral-to-debt ratio at which a position becomes undercollateralised. |
| `closeFactor` | Percentage | The maximum percentage of debt that can be liquidated in a single transaction. |
| `liquidationBonus` | Percentage | The discount offered to liquidators when purchasing seized collateral. |
| `minHealthFactor` | Scaled Uint | The absolute minimum health factor required to maintain a position (1.0 × SCALE). |
| `supplyCap` | Asset Amount | The global ceiling for aggregated asset deposits. |
| `borrowCap` | Asset Amount | The global ceiling for aggregated asset borrowing. |

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

## 7. Liquidation Engine

Liquidation is programmatically activated when an account's health factor drops below `minHealthFactor` (1.0). 

### 7.1 Debt Repayment Cap (Close Factor)
The maximum debt volume clearable per transaction is bounded by the `closeFactor`:
$$\text{Max Repayment} = \frac{\text{Debt} \times \text{closeFactor}}{100}$$

### 7.2 Liquidator Reward Calculation
To incentivise external capital, liquidators receive a premium on seized collateral:
$$\text{Seized Collateral Value} = \text{repayAmount} \times \left(1 + \frac{\text{liquidationBonus}}{100}\right)$$

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

* **Multi-Collateral Engine**: Cross-margin and isolated-margin risk management engines.
* **Dynamic Interest Rates**: Utilization-driven APR pricing loops.
* **Liquidation Auctions**: Replacing fixed bonuses with competitive premium bidding.
* **Keeper Network Integration**: Automated bots for zero-delay liquidation enforcement.