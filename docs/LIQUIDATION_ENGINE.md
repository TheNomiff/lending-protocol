# LiquidationEngine — Architecture Blueprint

> **Status:** Phases 1–3 ✅ complete and tested · Phases 4–6 ⏳ planned · **Lending integration 🟡 in progress**
>
> **Protocol phase:** [LENDING_PROTOCOL.md](./LENDING_PROTOCOL.md) Phase 6 — Liquidation Engine.
>
> **Scope:** Architecture, formulas, flows, roadmap, security analysis, and future vision. No implementation code.
>
> **Last synchronized:** June 2026 · see [LENDING_PROTOCOL.md §13](./LENDING_PROTOCOL.md#13-document-maintenance).

---

## Table of Contents

1. [Overview](#1-overview)
2. [Current Architecture](#2-current-architecture)
3. [Phase 1 (Completed)](#3-phase-1-completed)
4. [Phase 2 (Validation Layer)](#4-phase-2-validation-layer)
5. [Phase 3 (Preview System)](#5-phase-3-preview-system)
6. [Phase 4 (Multi-Asset Liquidation)](#6-phase-4-multi-asset-liquidation)
7. [Phase 5 (Dynamic Liquidation System)](#7-phase-5-dynamic-liquidation-system)
8. [Phase 6 (Professional Liquidation Engine)](#8-phase-6-professional-liquidation-engine)
9. [Security Considerations](#9-security-considerations)
10. [Testing Strategy](#10-testing-strategy)
11. [Audit Checklist](#11-audit-checklist)
12. [Long-Term Vision](#12-long-term-vision)

---

## 1. Overview

### What Is LiquidationEngine?

`LiquidationEngine` is the dedicated liquidation policy and calculation module of the lending protocol. It owns the rules that determine:

- How much debt a liquidator may repay in a single transaction (close factor).
- How much bonus collateral a liquidator receives for performing a liquidation (liquidation bonus).
- How seized collateral is computed from a repayment amount.
- (Future phases) Whether a position is eligible for liquidation, whether a liquidation improves solvency, and full liquidation previews for frontends and bots.

Today, the engine is a **pure calculation and parameter contract**. Execution—moving ETH, updating user balances, and emitting events—remains in `Lending.sol`. Over subsequent phases, validation and preview logic will migrate here so `Lending.sol` becomes a thin accounting shell around liquidation execution.

### Why Liquidation Logic Should Be Separated from Lending.sol

`Lending.sol` is the protocol's ledger. Its core job is to track who owns what: deposits, borrows, interest accrual, and liquidity pools. Liquidation is a *policy layer* applied on top of that ledger, not ledger logic itself.

Keeping liquidation rules inside `Lending.sol` causes:

| Problem | Effect |
| :--- | :--- |
| Growing `liquidate()` complexity | Harder to reason about state transitions |
| Parameter changes touching accounting code | Higher regression risk on deposit/borrow paths |
| Difficult isolated testing | Liquidation math tests require full Lending setup |
| Upgrade friction | Replacing liquidation policy requires redeploying or upgrading the entire core |

By extracting liquidation into `LiquidationEngine`, `Lending.sol` delegates "what are the liquidation numbers?" to a module that can evolve independently.

### Why Liquidation Logic Should Not Live Inside RiskEngine

`RiskEngine` governs **solvency and protocol safety boundaries**: health factor math, LTV limits, caps, pause switches, and eligibility checks (`canBorrow`, `canWithdraw`, `isLiquidatable`). Its outputs are boolean or ratio-based risk signals.

Liquidation mechanics are a different concern:

| RiskEngine | LiquidationEngine |
| :--- | :--- |
| "Is this position underwater?" | "How much can be liquidated?" |
| "Is post-withdraw collateral safe?" | "How much collateral does the liquidator seize?" |
| "Is HF below minimum?" | "Did HF improve after liquidation?" |
| Static risk parameters (LTV, threshold) | Dynamic liquidation incentives (bonus, close factor) |

Merging them would create a monolithic risk contract that mixes *preventive* controls (blocking unsafe actions) with *corrective* controls (liquidating unsafe positions). That blurs audit boundaries, increases contract size, and makes it harder to upgrade liquidation incentives without touching borrow/withdraw validation.

`RiskEngine` already documents that V3 assumes same-asset collateral and debt; multi-asset conversion belongs at the oracle and liquidation layers, not inside generic solvency checks.

### Benefits of Modular Architecture

#### Separation of Concerns

Each contract has a single, well-defined responsibility:

- **Lending** — accounting and asset flows.
- **RiskEngine** — solvency validation and emergency controls.
- **PriceOracle** — external price integrity.
- **LiquidationEngine** — liquidation policy and calculations.
- **Timelock** — delayed execution of privileged changes.

#### Upgradeability

Liquidation parameters and formulas change more often than core accounting. A standalone `LiquidationEngine` can be replaced or extended (e.g., dynamic bonuses in Phase 5) with minimal touch points in `Lending.sol`.

#### Auditability

Auditors can review liquidation math in isolation. The surface area for "incorrect seizure amount" bugs is confined to one module with view-only calculation functions.

#### Testability

Phase 1 already demonstrates this: unit tests call `calculateMaxLiquidation`, `calculateLiquidationBonus`, and `calculateSeizedCollateral` without deploying `Lending`, `PriceOracle`, or mock Chainlink feeds.

#### Protocol Scalability

As the protocol adds assets, batch liquidations, keeper integrations, and dynamic incentives, liquidation complexity grows faster than deposit/borrow complexity. A dedicated engine prevents `Lending.sol` from becoming unmaintainable.

---

## 2. Current Architecture

### Protocol Topology

The lending protocol is a layered stack. User actions enter at `Lending.sol`, which consults downstream modules for validation and pricing before updating state.

```
                    ┌─────────────────────────────────────┐
                    │              User                   │
                    │  (Depositor / Borrower / Liquidator)│
                    └──────────────────┬──────────────────┘
                                       │
                                       ▼
                    ┌─────────────────────────────────────┐
                    │            Lending.sol              │
                    │  deposit · borrow · withdraw        │
                    │  repay · liquidate                  │
                    │  (ledger + execution)               │
                    └──────────┬────────────┬─────────────┘
                               │            │
              validation       │            │  liquidation math
                               ▼            ▼
              ┌────────────────────┐   ┌─────────────────────┐
              │   RiskEngine.sol   │   │ LiquidationEngine   │
              │  HF · caps · pause │   │ closeFactor · bonus │
              │  isLiquidatable    │   │ seizure calculations│
              └─────────┬──────────┘   └─────────────────────┘
                        │
                        │  collateral/debt USD values
                        ▼
              ┌────────────────────┐
              │  PriceOracle.sol   │
              │  Chainlink feeds   │
              └─────────┬──────────┘
                        │
                        ▼
              ┌────────────────────┐
              │  Chainlink Feed  │
              └────────────────────┘

              ┌────────────────────┐
              │   Timelock.sol     │  (governance — queues owner actions
              │   delayed exec     │   on RiskEngine, PriceOracle, etc.)
              └────────────────────┘
```

### Liquidation-Specific Flow (Current)

```
Liquidator
    │
    │  liquidate(user, ETH)
    ▼
Lending.sol
    │
    ├─► RiskEngine.liquidationPaused()?  → revert if paused
    │
    ├─► accrue interest on user position
    │
    ├─► PriceOracle → USD values for HF
    │
    ├─► RiskEngine.healthFactor() + isLiquidatable()
    │       → revert if HF ≥ minHealthFactor
    │
    ├─► LiquidationEngine.calculateMaxLiquidation(debt)
    │       → cap repay amount
    │
    ├─► update borrowed / liquidity / totalBorrow
    │
    ├─► LiquidationEngine.calculateSeizedCollateral(repayAmount)
    │       → cap at user.deposited
    │
    ├─► verify ending HF > starting HF  (still in Lending today)
    │
    └─► transfer seized collateral to liquidator
```

### Contract Responsibilities

| Contract | Responsibility in Liquidation Context |
| :--- | :--- |
| **Lending.sol** | Entry point `liquidate()`. Accrues interest, updates user debt and collateral balances, moves ETH, refunds excess repayment, enforces HF-improvement check (today). |
| **RiskEngine.sol** | Computes health factor. Determines liquidation eligibility via `isLiquidatable(HF)`. Provides `liquidationPaused` circuit breaker. Does **not** own close factor or bonus (moved to LiquidationEngine). |
| **PriceOracle.sol** | Converts ETH amounts to USD for health factor calculations during liquidation eligibility checks. |
| **LiquidationEngine.sol** | Stores `closeFactor` and `liquidationBonus`. Pure view math: max liquidation, bonus, seized collateral. |
| **Timelock.sol** | (Planned integration) Delays owner updates to liquidation parameters. Currently integrated with `RiskEngine` and `PriceOracle` in test deployments; `LiquidationEngine` ownership not yet wired to Timelock. |

### Current Protocol Assumptions (V3)

- **Single collateral asset:** ETH.
- **Single debt asset:** ETH (borrowed native ETH).
- **Same-unit liquidation:** Repayment and seizure are both in ETH wei, so LiquidationEngine calculations operate in asset units without cross-asset conversion.
- **USD only for HF:** Oracle is used to value positions for solvency checks, not for seizure amount conversion.

---

## 3. Phase 1 (Completed)

### Objective

Establish `LiquidationEngine` as a standalone module owning liquidation **calculation** and **parameter governance**, with near-complete unit test coverage.

### Implemented Functions

| Function | Type | Description |
| :--- | :--- | :--- |
| `calculateMaxLiquidation(uint256 debtUsd)` | `view` | Maximum repayable debt in a single liquidation. |
| `calculateLiquidationBonus(uint256 repayAmount)` | `view` | Bonus portion of seized collateral. |
| `calculateSeizedCollateral(uint256 repayAmount)` | `view` | Total collateral seized (repay + bonus). |

> **Note:** Parameter name `debtUsd` reflects the long-term multi-asset design. In the current single-asset ETH protocol, `Lending.sol` passes total debt in **ETH wei**; percentage math is unit-agnostic.

### Admin Parameters

| Parameter | Default | Valid Range | Setter |
| :--- | :--- | :--- | :--- |
| `closeFactor` | `50` (50%) | `1` – `100` | `updateCloseFactor(uint256)` |
| `liquidationBonus` | `10` (10%) | `1` – `100` | `updateLiquidationBonus(uint256)` |
| `LIQUIDATION_PRECISION` | `100` (constant) | immutable | — |

Validation rules:

- `closeFactor == 0` or `> 100` → revert `InvalidCloseFactor`.
- `liquidationBonus == 0` or `> 100` → revert `InvalidBonus`.
- Setting a parameter to its current value → revert `ValueUnchanged`.

### Ownership Model

| Aspect | Current Behavior |
| :--- | :--- |
| Initial owner | `msg.sender` at deploy (constructor). |
| Transfer | `transferOwnership(address)` — owner only; `address(0)` rejected. |
| Parameter updates | Owner only via `onlyOwner` modifier. |
| Timelock | **Not yet integrated.** Owner is a direct EOA/contracts address. Planned: transfer ownership to `Timelock` and queue `updateCloseFactor` / `updateLiquidationBonus` through delayed execution (mirroring `RiskEngine` and `PriceOracle` test setup). |
| Guardian | No guardian role on LiquidationEngine. Emergency liquidation pause lives on `RiskEngine` (`pauseLiquidation`). |

### Events

- `CloseFactorUpdated(uint256 oldValue, uint256 newValue)`
- `LiquidationBonusUpdated(uint256 oldValue, uint256 newValue)`

### Formulas

All formulas use `LIQUIDATION_PRECISION = 100` as the percentage denominator.

#### Max Liquidation Formula

```
maxLiquidation = (debt × closeFactor) / LIQUIDATION_PRECISION
```

Equivalently:

```
maxLiquidation = debt × closeFactor / 100
```

#### Bonus Formula

```
bonus = (repayAmount × liquidationBonus) / LIQUIDATION_PRECISION
```

#### Seized Collateral Formula

```
seizedCollateral = repayAmount + bonus
                   = repayAmount + (repayAmount × liquidationBonus) / LIQUIDATION_PRECISION
                   = repayAmount × (1 + liquidationBonus / 100)
```

### Worked Examples (Defaults: closeFactor = 50%, bonus = 10%)

#### Example A — Max Liquidation

| Input | Value |
| :--- | :--- |
| Total debt | 40 ETH |
| closeFactor | 50% |

```
maxLiquidation = 40 × 50 / 100 = 20 ETH
```

A liquidator may repay up to **20 ETH** of the user's debt in one transaction.

#### Example B — Bonus and Seizure

| Input | Value |
| :--- | :--- |
| repayAmount | 10 ETH |
| liquidationBonus | 10% |

```
bonus            = 10 × 10 / 100 = 1 ETH
seizedCollateral = 10 + 1 = 11 ETH
```

The liquidator repays **10 ETH** of debt and receives **11 ETH** of collateral (10 ETH principal + 1 ETH bonus).

#### Example C — Full Liquidation Transaction (Conceptual)

| Position Before | Value |
| :--- | :--- |
| Collateral | 30 ETH |
| Debt (with interest) | 40 ETH |
| HF | Below `minHealthFactor` (liquidatable) |

Liquidator sends 25 ETH (exceeds max):

```
maxLiquidation = 40 × 50 / 100 = 20 ETH
repayAmount    = min(25, 20) = 20 ETH
extra refunded = 5 ETH

seizedCollateral = 20 × 1.10 = 22 ETH
capped at deposited = min(22, 30) = 22 ETH

Position after:
  debt       = 40 - 20 = 20 ETH
  collateral = 30 - 22 = 8 ETH
```

`Lending.sol` additionally requires `endingHF > startingHF` before the transaction succeeds.

### Current Limitations (Phase 1)

| Limitation | Detail |
| :--- | :--- |
| **Calculation only** | No `canLiquidate`, no HF-improvement validation, no preview. |
| **Validation in Lending** | Eligibility, pause checks, HF improvement still live in `Lending.sol`. |
| **No Lending constructor wiring** | `liquidationEngine` is a public state variable but not set in `Lending` constructor; integration tests for end-to-end liquidation are not yet present. |
| **Single asset** | No cross-asset price conversion for seizure. |
| **Static parameters** | Fixed close factor and bonus; no health-factor-dependent dynamics. |
| **No batch / queue** | One user per `liquidate()` call. |
| **No Timelock on parameters** | Direct owner updates without delay. |
| **Seizure cap in Lending** | `min(seized, user.deposited)` enforced in `Lending`, not LiquidationEngine. |

### Phase 1 Test Coverage

| Test Suite | Focus |
| :--- | :--- |
| `LiquidationEngineConstructorTest` | Owner set at deploy. |
| `LiquidationEngineCalculationTest` | All three calculation functions, including zero repay bonus. |
| `LiquidationEngineParametersTest` | Valid/invalid bounds, unchanged-value reverts, non-owner reverts. |
| `LiquidationEngineOwnershipTest` | Transfer ownership, zero-address guard, non-owner rejection. |

---

## 4. Phase 2 (Validation Layer)

> **Implementation status:** ✅ Complete — `canLiquidate`, `remainingDebtAfterLiquidation`, and `remainingCollateralAfterSeizure` are implemented in `LiquidationEngine.sol`. Health-factor improvement check remains in `Lending.sol` (composite `validateLiquidation` deferred).

### Objective

Move liquidation **validation logic** from `Lending.sol` into `LiquidationEngine`, so `Lending` only executes state updates after the engine approves the liquidation math.

### Proposed Functions

| Function | Purpose |
| :--- | :--- |
| `canLiquidate(uint256 healthFactor)` | Returns whether HF is below liquidation threshold (delegates to shared `minHealthFactor` constant or accepts threshold as input). |
| `isHealthFactorImproved(uint256 hfBefore, uint256 hfAfter)` | Returns whether post-liquidation HF strictly improved. |
| `remainingDebtAfterLiquidation(uint256 currentDebt, uint256 repayAmount)` | `currentDebt - repayAmount` with overflow/underflow safety. |
| `remainingCollateralAfterSeizure(uint256 currentCollateral, uint256 seizedCollateral)` | `currentCollateral - seizedCollateral` with cap logic. |

Optional composite validator:

| Function | Purpose |
| :--- | :--- |
| `validateLiquidation(...)` | Single call returning success/failure and all computed amounts for `Lending` to execute. |

### Why These Belong in LiquidationEngine

| Logic | Why not RiskEngine? | Why not Lending? |
| :--- | :--- | :--- |
| `canLiquidate` | RiskEngine already has `isLiquidatable`; LiquidationEngine can wrap it or accept HF as input to keep liquidation eligibility at the liquidation boundary. | Lending should not own policy. |
| `isHealthFactorImproved` | This is a post-liquidation *mechanism* check, not a preventive risk gate. | Keeps `liquidate()` readable. |
| `remainingDebt` / `remainingCollateral` | Pure liquidation accounting helpers. | Testable without full Lending harness. |

### How This Simplifies Lending.sol

**Before (today):**

```
liquidate():
  pause check → RiskEngine
  accrue interest
  HF check → RiskEngine + Oracle
  cap repay → LiquidationEngine
  update balances
  seize → LiquidationEngine
  HF improved check → internal
  transfer ETH
```

**After Phase 2:**

```
liquidate():
  pause check → RiskEngine (unchanged)
  accrue interest
  (collateralUsd, debtUsd, HF) → Oracle + RiskEngine
  LiquidationEngine.validateLiquidation(...) → amounts + approval
  update balances (pure accounting)
  transfer ETH
```

`Lending.sol` becomes: gather inputs → ask engine → execute.

### How This Improves Testing

- **Unit tests:** `isHealthFactorImproved(0.9e18, 0.95e18)` → true; equal HF → false.
- **Property tests:** `remainingDebt + repayAmount == currentDebt` always.
- **Integration tests:** Mock HF values without simulating full price crashes.

### Example Liquidation Flows (Phase 2)

#### Flow 1 — Standard Partial Liquidation

```
1. User position: 30 ETH collateral, 40 ETH debt, HF = 0.85 (< 1.0)
2. Liquidator calls liquidate with 15 ETH
3. Lending accrues interest, reads HF_before = 0.85
4. LiquidationEngine:
     maxLiquidation = 20 ETH
     repayAmount = 15 ETH (within cap)
     seized = 16.5 ETH (15 × 1.10)
     HF_after (simulated) = 0.92
     isHealthFactorImproved(0.85, 0.92) = true
5. Lending executes balance updates and transfers 16.5 ETH to liquidator
```

#### Flow 2 — Rejected: No HF Improvement

```
1. HF_before = 0.80
2. Small repayAmount = 1 ETH → seized = 1.1 ETH
3. HF_after = 0.79 (insufficient improvement or worsened due to rounding)
4. LiquidationEngine.validateLiquidation → revert
5. No state change
```

#### Flow 3 — Rejected: Not Liquidatable

```
1. HF = 1.05
2. canLiquidate → false
3. Revert before any token movement
```

### Phase 2 Dependencies

- `Lending` must wire `liquidationEngine` in constructor or initializer.
- Decide whether `canLiquidate` reads `minHealthFactor` from `RiskEngine` (external call) or LiquidationEngine stores a cached copy updated via governance.
- **Recommendation:** LiquidationEngine calls `RiskEngine.isLiquidatable(HF)` to avoid duplicating threshold logic.

---

## 5. Phase 3 (Preview System)

> **Implementation status:** ✅ Complete — `previewLiquidation` and `LiquidationPreview` struct implemented; unit tests in `test/unit/liquidation/LiquidationEnginepreviewLiquidation.t.sol`. Not yet consumed by `Lending.liquidate()`.

### Objective

Provide a single read-only entry point that returns the full liquidation picture for any position and proposed repayment, enabling frontends, dashboards, and bots to display accurate data without simulating transactions.

### `previewLiquidation()`

#### Inputs

| Input | Description |
| :--- | :--- |
| `collateralAmount` | User's deposited collateral (native units). |
| `debtAmount` | User's total debt including accrued interest (native units). |
| `repayAmount` | Proposed liquidation repayment (native units). |
| `collateralUsd` | USD value of collateral (from Oracle). |
| `debtUsd` | USD value of debt (from Oracle). |
| `healthFactor` | Pre-computed HF (or engine computes from USD inputs). |

Alternatively, a thinner API:

| Input | Description |
| :--- | :--- |
| `repayAmount` | Proposed repayment. |
| `collateralUsd`, `debtUsd` | Position values in USD. |

with collateral/debt amounts passed for seizure capping.

#### Outputs

| Output | Description |
| :--- | :--- |
| `maxLiquidation` | Maximum allowed repay in asset units. |
| `repayAmount` | Effective repay after capping (`min(proposed, max)`). |
| `bonus` | Liquidator bonus amount. |
| `collateralToSeize` | Total seizure before deposit cap. |
| `effectiveSeizure` | `min(collateralToSeize, collateralAmount)`. |
| `remainingDebt` | Debt after liquidation. |
| `remainingCollateral` | Collateral after seizure. |
| `healthFactorBefore` | HF prior to liquidation. |
| `healthFactorAfter` | Simulated HF after liquidation. |
| `canExecute` | Whether liquidation would pass all validation rules. |
| `refundAmount` | Excess ETH returned to liquidator if proposed > max. |

#### Simulated HF After Liquidation

Using RiskEngine formula:

```
collateralAdjusted_before = collateralUsd × liquidationThreshold / 100
HF_before = collateralAdjusted_before × PRECISION / debtUsd

remainingCollateralUsd = collateralUsd × (remainingCollateral / collateralAmount)  [single-asset proportional]
remainingDebtUsd = debtUsd × (remainingDebt / debtAmount)

collateralAdjusted_after = remainingCollateralUsd × liquidationThreshold / 100
HF_after = collateralAdjusted_after × PRECISION / remainingDebtUsd
```

For same-asset ETH protocol, USD ratios equal asset ratios when a single oracle price applies to both.

### Frontend Usage

```
1. Indexer detects HF < 1.0 for user U
2. Frontend calls previewLiquidation(U, repayAmount) via multicall or direct RPC
3. UI displays:
   - "Repay up to 20 ETH"
   - "Receive ~22 ETH collateral (10% bonus)"
   - "HF: 0.85 → 0.95"
4. User confirms wallet transaction with exact repayAmount
```

### Bot / Keeper Usage

```
1. Bot scans positions off-chain using same HF formula
2. On-chain previewLiquidation confirms math matches (oracle drift protection)
3. Bot submits liquidate() only when preview.canExecute == true
4. Gas estimation uses preview outputs for exact value to send
```

### Phase 3 Design Principles

- **Pure `view`:** No state changes; safe for `eth_call`.
- **Deterministic:** Same inputs always produce same outputs at same block.
- **Mirrors execution:** Preview must use identical formulas as `validateLiquidation` to prevent UX mismatches.

---

## 6. Phase 4 (Multi-Asset Liquidation)

### Objective

Transition from a single-asset ETH protocol to a multi-collateral, stablecoin-debt model where seizure requires cross-asset price conversion.

### Target Asset Matrix

| Role | Asset | Notes |
| :--- | :--- | :--- |
| Collateral | ETH | Native, 18 decimals |
| Collateral | WBTC | 8 decimals, volatile |
| Collateral | LINK | 18 decimals, volatile |
| Debt | Stablecoin (e.g., USDC) | 6 decimals, pegged to USD |

A user might deposit ETH and WBTC, borrow USDC, and be liquidated by repaying USDC to receive a mix of ETH and WBTC (or a chosen collateral asset, depending on protocol design).

### Why Oracle Integration Becomes Necessary

In Phase 1, repayment and seizure share the same unit (ETH). In multi-asset mode:

```
Liquidator repays:  USDC (debt asset)
Liquidator receives: ETH or WBTC (collateral asset)
```

The bonus is defined in **value terms**, not unit terms:

```
seizedValueUsd = repayUsd × (1 + liquidationBonus / 100)
seizedEth      = seizedValueUsd / ethPriceUsd  (with decimal normalization)
```

Without oracle prices per asset, the engine cannot convert repayment into correct collateral amounts.

### Multi-Asset Seizure Formulas

#### Step 1 — Cap repayment

```
maxRepay = (debtAmount × closeFactor) / 100        [debt token units]
repayAmount = min(proposedRepay, maxRepay)
```

#### Step 2 — Compute seized value in USD

```
repayUsd = repayAmount × debtPriceUsd / debtDecimals
bonusUsd = repayUsd × liquidationBonus / 100
seizedValueUsd = repayUsd + bonusUsd
```

#### Step 3 — Convert to collateral asset

```
collateralPriceUsd = oracle price of chosen collateral
seizedCollateral = seizedValueUsd × collateralDecimals / collateralPriceUsd
```

#### Combined formula

```
seizedCollateral = (repayAmount × debtPrice × (100 + liquidationBonus) × collateralDecimals)
                   / (100 × collateralPrice × debtDecimals)
```

(Adjust for oracle feed decimals, e.g., Chainlink 8-decimal USD feeds.)

### Collateral Selection Strategies

| Strategy | Description |
| :--- | :--- |
| **Liquidator specifies asset** | Liquidator chooses which collateral to seize (Aave-style). |
| **Protocol priority** | Seize lowest-quality or most liquid collateral first. |
| **Proportional** | Seize across all collateral types proportionally. |

Phase 4 design should pick one strategy and document it; Aave allows liquidator to choose collateral asset.

### Precision Considerations

| Topic | Guidance |
| :--- | :--- |
| Oracle decimals | Chainlink feeds often 8 decimals; tokens 6 or 18. Normalize to a common precision (e.g., 1e18) before division. |
| Division order | Multiply before divide to minimize precision loss: `(a × b × c) / (d × e)`. |
| Minimum seizure | Revert if seized amount rounds to zero but repay is non-zero. |
| Dust | Define minimum liquidation size to avoid uneconomic liquidations. |

### Rounding Concerns

| Scenario | Risk | Mitigation |
| :--- | :--- | :--- |
| Seized collateral rounds down | Liquidator gets less bonus; may not liquidate | Round in favor of protocol for seizure; document bias |
| Debt repayment rounds up | User loses extra collateral | Round repay down, seizure down |
| Multi-hop conversion | Cumulative rounding error | Use full-precision intermediates; fuzz test bounds |
| WBTC 8 vs USDC 6 decimals | Scale mismatch | Explicit `decimals()` per asset registry |

### Phase 4 Architecture Additions

- **Asset registry** in Lending or separate module: token addresses, decimals, oracle feed IDs.
- **LiquidationEngine** accepts asset identifiers and oracle-derived prices.
- **PriceOracle** extended to multi-feed (already planned for protocol; LiquidationEngine consumes normalized USD values).

---

## 7. Phase 5 (Dynamic Liquidation System)

### Objective

Replace static `closeFactor` and `liquidationBonus` with health-factor-dependent curves that strengthen incentives as positions become more unhealthy, improving protocol resilience during stress.

### Dynamic Liquidation Bonus

#### Example Curve

| Health Factor | Liquidation Bonus |
| :--- | :--- |
| HF 0.95 | 5% |
| HF 0.85 | 10% |
| HF 0.75 | 15% |

#### Rationale

- **Mildly unhealthy positions (HF ≈ 0.95):** Lower bonus sufficient to attract liquidators; protects borrower collateral.
- **Deeply unhealthy positions (HF ≈ 0.75):** Higher bonus compensates for volatility risk, gas, and slippage; speeds restoration of solvency.
- **Prevents bad debt:** As HF drops, protocol trades collateral for faster cleanup.

#### Formula (Piecewise Linear)

```
if HF >= 0.95: bonus = 5%
if HF <= 0.75: bonus = 15%
else: bonus = 5% + (0.95 - HF) / (0.95 - 0.75) × (15% - 5%)
```

Governance sets breakpoints and min/max bonus; Timelock queues changes.

### Dynamic Close Factor

#### Example Curve

| Health Factor | Close Factor |
| :--- | :--- |
| HF 0.95 | 25% |
| HF 0.85 | 50% |
| HF 0.70 | 100% |

#### Rationale

- **Near-threshold positions:** Small partial liquidations avoid over-punishing borrowers who may recover.
- **Severely underwater positions:** Allow full debt clearance in one tx to minimize bad debt accumulation.
- **Gas efficiency:** Deep positions may need 100% close factor so liquidators do not pay multiple transactions.

### Incentive Design

#### Liquidator Incentives

| Mechanism | Role |
| :--- | :--- |
| Liquidation bonus | Direct profit: receive more collateral value than debt repaid. |
| Dynamic bonus | Higher profit when protocol is at greater risk. |
| Partial liquidation | Liquidators can size positions for gas/profit optimization. |
| Batch liquidation (Phase 6) | Economies of scale for professional keepers. |

#### Protocol Safety

| Mechanism | Role |
| :--- | :--- |
| Close factor cap | Prevents single-tx total wipe of borderline positions (when HF not critically low). |
| HF improvement check | Ensures liquidation actually helps solvency. |
| Liquidation pause | Guardian can halt during oracle anomalies. |
| Dynamic close factor at low HF | Maximizes debt recovery before insolvency. |

#### Bad Debt Prevention

Bad debt occurs when collateral value < debt value and no liquidator acts profitably.

| Lever | Effect |
| :--- | :--- |
| Higher bonus at low HF | Makes unprofitable positions profitable to liquidate |
| 100% close factor at HF < 0.70 | Allows full cleanup in one shot |
| Minimum HF for borrow (RiskEngine) | Prevents origination too close to liquidation |
| Oracle staleness guards | Prevents false solvency during feed outages |

### Phase 5 Governance

- Dynamic curve parameters are high-impact; all updates via Timelock.
- Consider guardian-only **temporary** bonus boost during market crashes (optional, separate from curve).

---

## 8. Phase 6 (Professional Liquidation Engine)

### Objective

Institutional-grade liquidation infrastructure: optimal partial liquidations, batch execution, priority ordering, and keeper-native interfaces.

### Partial Liquidation Optimization

#### Problem

A fixed close factor may repay more debt than necessary to restore HF ≥ 1.0, over-seizing borrower collateral.

#### Solution — Minimum Repayment to Restore Solvency

Compute the minimum `repayAmount` such that `HF_after >= minHealthFactor`:

```
Target: (remainingCollateralUsd × threshold / 100) / remainingDebtUsd >= minHF

Solve for repayAmount (USD):
  remainingDebtUsd = debtUsd - repayUsd
  remainingCollateralUsd = collateralUsd - seizedValueUsd
  seizedValueUsd = repayUsd × (1 + bonus/100)

Approximate (single collateral, static bonus):
  repayUsd_min ≈ debtUsd - (collateralUsd × threshold / 100) / minHF
                 ─────────────────────────────────────────────────
                        1 + bonus/100
```

LiquidationEngine exposes `calculateMinRepayForSolvency(...)` for bots to liquidate efficiently and `previewLiquidation` to show "optimal" vs "max" repay.

Benefits:

- Better borrower experience (less collateral lost).
- Lower protocol bad debt (precise solvency restoration).
- Competitive advantage for sophisticated liquidators.

### Batch Liquidation — `liquidateMany()`

#### Design

```
liquidateMany(
  users[]        — addresses to liquidate
  repayAmounts[] — per-user repay amounts
) → results per user (success, seized, HF delta)
```

#### Gas Considerations

| Factor | Impact |
| :--- | :--- |
| Per-user oracle reads | Batch with cached prices at block start |
| Storage updates | Amortize fixed costs over N users |
| ETH transfers | N transfers; consider WETH or internal balance for keepers |
| Revert policy | `try/catch` per user vs all-or-nothing |
| Block gas limit | Cap batch size (e.g., 10–50 users per tx) |

#### Recommended Pattern

- **All-or-nothing** for atomic DeFi composability.
- **Per-item try** for keeper bots that want partial success (optional secondary function).

### Liquidation Queue System

Off-chain indexers build a priority queue; on-chain optional `getNextLiquidatable` is expensive. Recommended hybrid:

```
Off-chain:
  1. Index all positions with HF < 1.0
  2. Sort by HF ascending (most unhealthy first)
  3. Filter by estimated profit (bonus × repay - gas)

On-chain:
  liquidateMany(sortedUsers, amounts) — executor provides order
```

#### Priority Ordering Rationale

| Priority | Reason |
| :--- | :--- |
| Lowest HF first | Highest bad debt risk |
| Largest debt × deficit | Maximizes protocol recovery |
| Highest expected profit | Maximizes liquidator participation |

Optional: protocol-run **liquidation auction** module (future) for MEV redistribution.

### Keeper / Bot Integration

#### Off-Chain Bot Loop

```
every block / price update:
  1. Fetch oracle prices
  2. Compute HF for all borrowers (subgraph or direct RPC)
  3. For HF < 1.0:
       previewLiquidation(user, optimalRepay)
  4. If profitable:
       submit liquidate() or liquidateMany()
  5. Monitor revert reasons and adjust
```

#### On-Chain Interfaces for Bots

| Interface | Use |
| :--- | :--- |
| `previewLiquidation` | Profit estimation |
| `calculateMinRepayForSolvency` | Optimal sizing |
| `canLiquidate` | Fast filter |
| Events on `RiskEngine` pause | Stop bot when `LiquidationPaused` |

#### MEV Considerations

- Liquidations are competitive; bots use flashbots/private RPCs.
- Dynamic bonus may be captured by searchers; protocol benefits from fast liquidations regardless.

---

## 9. Security Considerations

### Oracle Manipulation

| Risk | Description |
| :--- | :--- |
| Price spike | Inflated collateral USD → positions appear healthy → no liquidation |
| Price crash | Deflated collateral → unfair liquidations |
| Stale price | Outdated feed during volatility |

**Mitigations:**

- Chainlink aggregators with staleness checks (`PriceOracle.staleTime`).
- Guardian `pauseLiquidation` on `RiskEngine` during anomalies.
- Multi-oracle or TWAP for high-value collateral (future).
- LiquidationEngine never writes prices; only consumes normalized values from `PriceOracle`.

### Flash Loan Attacks

| Attack | Description |
| :--- | :--- |
| Manipulate HF via flash borrow | Temporarily distort position or pool state |
| Oracle manipulation + liquidate | Classic DeFi attack vector |

**Mitigations:**

- HF computed from user position state, not manipulable pool ratios for this protocol design.
- Same-block borrow-and-liquidate self-attack: ensure liquidator cannot liquidate own position profitably via flash manipulation (review in multi-asset phase).
- Close factor limits single-tx extraction.
- Consider cooldown or same-block borrow/liquidate restrictions if vulnerabilities emerge.

### Incorrect Bonus Calculations

| Risk | Impact |
| :--- | :--- |
| Bonus too high | Protocol loses collateral, insolvency |
| Bonus too low | No liquidators, bad debt |

**Mitigations:**

- Hard cap on `liquidationBonus` (≤ 100% in Phase 1; governance may lower max in production e.g., ≤ 25%).
- Unit tests for all formula edge cases.
- Fuzz: `seizedCollateral >= repayAmount` always.
- Timelock on parameter updates.

### Over-Liquidation

| Risk | Description |
| :--- | :--- |
| Repay > maxLiquidation | Excess debt cleared against policy |
| Seize > deposited | User loses more collateral than exists |

**Mitigations:**

- Cap `repayAmount` at `maxLiquidation` (Lending today).
- Cap seizure at `user.deposited` (Lending today).
- Phase 2: `remainingCollateralAfterSeizure` in engine with explicit revert on underflow.

### Under-Liquidation

| Risk | Description |
| :--- | :--- |
| HF not improved | Position stays unhealthy; wasted gas |
| Rounding leaves dust debt | Zombie positions |

**Mitigations:**

- `isHealthFactorImproved` check (strict `>` not `>=`).
- Minimum liquidation size threshold.
- Phase 6 optimal repay to reach HF ≥ 1.0.

### Precision Loss

| Risk | Description |
| :--- | :--- |
| Integer division truncation | Systematic bias in seizure amounts |
| Multi-asset decimal mismatch | Wrong seizure magnitude |

**Mitigations:**

- Multiply-before-divide ordering.
- Document rounding direction (protocol-favorable).
- Fuzz bounds on value conservation.

### Rounding Errors

| Scenario | Mitigation |
| :--- | :--- |
| Small repay → zero seizure | Revert `LiquidationTooSmall` |
| HF improvement fails due to rounding | Require minimum repay increment |
| WBTC/USDC conversion | Dedicated per-asset fuzz suite |

### Reentrancy Risks

| Surface | Risk |
| :--- | :--- |
| `liquidate()` ETH transfers | Reenter during `call{value}` |
| External oracle callbacks | Not applicable to Chainlink latestRound |

**Mitigations:**

- `ReentrancyGuard` on `Lending.liquidate` (already present).
- Checks-effects-interactions: update all balances before external transfers.
- LiquidationEngine remains view-only for calculations (no external calls in math path).

---

## 10. Testing Strategy

### Phase 1 (Completed)

| Type | Examples |
| :--- | :--- |
| **Unit** | `calculateMaxLiquidation(40 ether) == 20 ether`; bonus 10% of 10 ether = 1 ether |
| **Unit** | `updateCloseFactor(0)` reverts; `updateCloseFactor(50)` when already 50 reverts |
| **Unit** | Non-owner cannot update parameters |
| **Integration** | (Pending) Lending + LiquidationEngine wired liquidation E2E |
| **Fuzz** | (Recommended) `debt`, `closeFactor` → `maxLiquidation <= debt` |
| **Invariant** | (Recommended) `seizedCollateral >= repayAmount` for all valid inputs |

### Phase 2 (Validation Layer) — ✅ Unit tests complete

| Type | Status | Examples |
| :--- | :--- | :--- |
| **Unit** | ✅ | `canLiquidate` aligned with `RiskEngine.isLiquidatable` |
| **Unit** | ✅ | `remainingDebtAfterLiquidation`; `remainingCollateralAfterSeizure` |
| **Unit** | ⬜ | `isHealthFactorImproved` (not implemented; check remains in Lending) |
| **Integration** | ⬜ | Full `liquidate()` through Lending with engine validation only |
| **Fuzz** | 🟡 | Recommended |
| **Invariant** | ⬜ | Successful liquidation implies `HF_after > HF_before` at integration level |

### Phase 3 (Preview System) — ✅ Unit tests complete

| Type | Status | Examples |
| :--- | :--- | :--- |
| **Unit** | ✅ | `LiquidationEnginepreviewLiquidation.t.sol` — preview outputs vs calculations |
| **Integration** | ⬜ | `previewLiquidation` == execution result (Lending not wired) |
| **Fuzz** | 🟡 | Recommended |
| **Invariant** | ✅ | `repayAmount <= maxLiquidation` in preview (unit level) |

### Phase 4 (Multi-Asset)

| Type | Examples |
| :--- | :--- |
| **Unit** | ETH collateral / USDC debt seizure with mock prices |
| **Unit** | WBTC 8-decimal and USDC 6-decimal conversion |
| **Integration** | Liquidate USDC debt, receive WBTC collateral |
| **Fuzz** | Random prices/decimals → no overflow, seizure ≤ collateral |
| **Invariant** | `seizedValueUsd <= collateralValueUsd` at liquidation time |

### Phase 5 (Dynamic System)

| Type | Examples |
| :--- | :--- |
| **Unit** | Bonus at HF 0.95, 0.85, 0.75 matches curve |
| **Unit** | Close factor at boundaries |
| **Fuzz** | Monotonicity: lower HF → higher bonus and close factor |
| **Invariant** | Bonus and close factor always within governance bounds |

### Phase 6 (Professional Engine)

| Type | Examples |
| :--- | :--- |
| **Unit** | `calculateMinRepayForSolvency` restores HF ≥ 1.0 |
| **Integration** | `liquidateMany` with 5 users; gas profiling |
| **Fuzz** | Batch with random subset of liquidatable users |
| **Invariant** | Total protocol collateral + debt conservation per successful liquidation |

### Cross-Phase Testing Infrastructure

| Tool | Role |
| :--- | :--- |
| `LiquidationTestBase` | Deploy engine, common assertions |
| `LendingTestBase` | Full stack with oracle, risk, timelock |
| Fork tests | Mainnet Chainlink feed behavior |
| CI | Maintain near-100% coverage on LiquidationEngine per phase |

---

## 11. Audit Checklist

Auditors should verify each item before production deployment.

### Parameters & Governance

- [ ] `closeFactor` bounded (1–100); zero and >100 rejected
- [ ] `liquidationBonus` bounded (1–100); zero and >100 rejected
- [ ] Parameter changes emit events with old and new values
- [ ] `ValueUnchanged` prevents no-op governance txs wasting gas
- [ ] Ownership transfer rejects `address(0)`
- [ ] Timelock owns LiquidationEngine in production deployment
- [ ] No direct EOA owner in production
- [ ] Dynamic curve parameters (Phase 5) bounded and Timelock-gated

### Calculation Correctness

- [ ] `maxLiquidation = debt × closeFactor / 100` (integer division documented)
- [ ] `bonus = repay × bonus% / 100`
- [ ] `seized = repay + bonus` (not double-counting bonus)
- [ ] Multi-asset conversion uses correct decimal scales (Phase 4)
- [ ] Rounding direction documented and consistently applied
- [ ] Zero repay returns zero seizure; zero debt returns zero max liquidation

### Validation Logic (Phase 2+)

- [ ] HF improvement strictly required (`>` not `>=`)
- [ ] Liquidation blocked when `RiskEngine.liquidationPaused`
- [ ] Liquidation blocked when HF ≥ `minHealthFactor`
- [ ] `repayAmount` capped at `maxLiquidation`
- [ ] Seizure capped at user collateral balance
- [ ] `canLiquidate` consistent with `RiskEngine.isLiquidatable`

### Oracle Dependency (Phase 4+)

- [ ] Stale price rejection in `PriceOracle`
- [ ] Invalid/zero price rejection
- [ ] LiquidationEngine does not cache prices across blocks incorrectly
- [ ] Pause path when oracle is unreliable

### Economic Security

- [ ] Maximum bonus cannot drain protocol collateral in single tx
- [ ] Close factor prevents unintended full liquidation at borderline HF (static phase)
- [ ] Dynamic close factor reaches 100% only at critically low HF (Phase 5)
- [ ] Bad debt scenarios identified and mitigated (bonus curve, min repay)

### Integration with Lending

- [ ] `liquidationEngine` immutable or properly initialized; not zero address
- [ ] Reentrancy guard on `liquidate()`
- [ ] CEI pattern: state updates before ETH transfers
- [ ] Excess repay refunded to liquidator
- [ ] Interest accrued before liquidation amounts computed
- [ ] `totalBorrow`, `totalLiquidity`, user balances consistent after liquidation

### Access Control

- [ ] Only owner can update parameters
- [ ] No unprivileged parameter mutation
- [ ] Guardian cannot change liquidation parameters (only pause via RiskEngine)

### Batch / Advanced (Phase 6)

- [ ] `liquidateMany` gas limits documented
- [ ] Partial batch failure policy clear
- [ ] No cross-user balance corruption in batch

---

## 12. Long-Term Vision

### Target State (All Phases Complete)

After Phases 1–6, `LiquidationEngine` is the **single source of truth** for liquidation policy:

```
┌─────────────────────────────────────────────────────────────┐
│                    LiquidationEngine                        │
│  ┌─────────────┐ ┌──────────────┐ ┌─────────────────────┐  │
│  │ Calculations│ │  Validation  │ │  Preview / Optimize │  │
│  │ max · bonus │ │ canLiquidate │ │ previewLiquidation  │  │
│  │ seize · min │ │ HF improved  │ │ minRepayForSolvency │  │
│  └─────────────┘ └──────────────┘ └─────────────────────┘  │
│  ┌─────────────┐ ┌──────────────┐ ┌─────────────────────┐  │
│  │  Dynamic    │ │ Multi-Asset  │ │  Batch / Queue API  │  │
│  │  bonus · CF │ │ oracle math  │ │  liquidateMany      │  │
│  └─────────────┘ └──────────────┘ └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    Lending.sol executes
                    (thin accounting shell)
```

`Lending.sol` liquidate path:

1. Accrue interest.
2. Read prices from `PriceOracle`.
3. Call `LiquidationEngine.previewLiquidation` or `validateLiquidation`.
4. Apply balance deltas.
5. Transfer assets.

`RiskEngine` remains the authority on **whether** positions are solvent for borrows/withdrawals and provides `isLiquidatable`, pause flags, and HF formula constants (`liquidationThreshold`, `minHealthFactor`).

### Conceptual Comparison

#### Aave

| Aspect | Aave | This Protocol (Target) |
| :--- | :--- | :--- |
| Architecture | Pool-based aTokens/debtTokens; liquidation in Pool | Modular engines; Lending ledger + LiquidationEngine |
| Liquidation bonus | Per-asset config in Pool | Centralized in LiquidationEngine; dynamic curves in Phase 5 |
| Close factor | Protocol-wide, can be 100% for small positions | Configurable; dynamic by HF in Phase 5 |
| Multi-asset | Native multi-collateral | Phase 4 with oracle per asset |
| Preview | UI uses subgraph + on-chain views | Native `previewLiquidation` |
| Governance | Aave Governance + timelock | Timelock on parameter updates |

**Alignment:** Separation of liquidation math from core pool accounting; per-asset bonus and multi-collateral seizure.

**Differentiation:** Explicit phased extraction into `LiquidationEngine` rather than monolithic pool contract.

#### Compound

| Aspect | Compound | This Protocol (Target) |
| :--- | :--- | :--- |
| Architecture | cToken markets; `liquidateBorrow` in cToken | Single Lending + engines |
| Liquidation | Fixed close factor (50%); collateral seized via price oracle | Same default 50%; evolving to dynamic |
| Incentive | `liquidationIncentive` per market | `liquidationBonus` in LiquidationEngine |
| Complexity | Per-market parameters | Central engine with asset registry (Phase 4) |

**Alignment:** Close factor cap, oracle-based seizure, liquidator bonus model.

**Differentiation:** Modular upgrade path; batch liquidation and optimal partial liquidation (Phase 6) as first-class design goals.

#### Morpho

| Aspect | Morpho | This Protocol (Target) |
| :--- | :--- | :--- |
| Architecture | Optimizer on top of Compound/Aave; peer-matched liquidity | Standalone protocol with custom engines |
| Liquidation | Delegates to underlying pool liquidation | Native LiquidationEngine |
| Efficiency | Gas optimization via matching | Gas optimization via batch + preview APIs |
| Risk | Isolated markets (Morpho Blue) | RiskEngine caps + dynamic liquidation incentives |

**Alignment:** Focus on liquidation efficiency and bad debt minimization.

**Differentiation:** Custom liquidation module not tied to Compound/Aave; dynamic HF-based curves and keeper-oriented preview/batch APIs designed in from Phase 3–6.

### Success Criteria

The LiquidationEngine roadmap is complete when:

1. **100% of liquidation math and validation** lives in `LiquidationEngine`, not `Lending.sol`.
2. **Frontends and bots** rely on `previewLiquidation` without custom off-chain reimplementation.
3. **Multi-asset seizure** is correct across ETH, WBTC, LINK collateral and stablecoin debt.
4. **Dynamic incentives** respond to health factor without manual governance intervention during normal operations.
5. **Professional keepers** can batch-liquidate profitably with documented gas budgets.
6. **Auditors** can review liquidation policy in one module with a completed checklist (Section 11).
7. **Timelock** governs all parameter changes with no direct owner bypass.

---

## Appendix A — Health Factor Reference (RiskEngine)

Used by liquidation eligibility and preview simulations:

```
collateralAdjusted = collateralUsd × liquidationThreshold / 100
healthFactor       = collateralAdjusted × PRECISION / debtUsd

isLiquidatable     = healthFactor < minHealthFactor   (default minHF = 1e18)
```

Default `liquidationThreshold = 75%` means collateral is haircutted before HF comparison.

---

## Appendix B — Phase Roadmap Summary

| Phase | Status | Deliverable |
| :--- | :--- | :--- |
| **1** | ✅ Complete | Calculation functions, static parameters, unit tests |
| **2** | ✅ Complete | Validation helpers (`canLiquidate`, `remainingDebt`, `remainingCollateral`) |
| **3** | ✅ Complete | `previewLiquidation` for UX and bots |
| **4** | ⏳ Planned | Multi-asset oracle-based seizure — [MULTI_ASSET_LENDING.md](./MULTI_ASSET_LENDING.md) Phase 7 |
| **5** | ⏳ Planned | Dynamic bonus and close factor curves |
| **6** | ⏳ Planned | Optimal partial liquidation, batch, keeper integration |

**Integration gaps (Phase 6 protocol milestone):**

| Item | Status |
| :--- | :---: |
| `LiquidationEngine` in `Lending` constructor | ⬜ |
| End-to-end `Lending.liquidate()` tests | ⬜ |
| `previewLiquidation` used by `Lending` | ⬜ |
| `totalSupply` decrement on seizure | ⬜ |

---

## Appendix C — Related Documentation

| Document | Content |
| :--- | :--- |
| [LENDING_PROTOCOL.md](./LENDING_PROTOCOL.md) | Master architecture, module status, Phase 6 roadmap |
| [RISK_ENGINE.md](./RISK_ENGINE.md) | Health factor, caps, pause, `isLiquidatable` |
| [TIMELOCK.md](./TIMELOCK.md) | Governance delay for close factor / bonus updates |
| [MULTI_ASSET_LENDING.md](./MULTI_ASSET_LENDING.md) | Cross-asset liquidation (Phase 7 blueprint) |
| [PRICE_ORACLE.md](./PRICE_ORACLE.md) | Oracle pricing for multi-asset seizure |
| [README.md](../README.md) | Repository overview |

---

## Appendix D — Document Maintenance

| When | Update |
| :--- | :--- |
| New LiquidationEngine functions | Relevant phase section + Appendix B |
| Lending integration merged | Clear integration gaps table in Appendix B |
| Master Phase 6 status changes | Status header + [LENDING_PROTOCOL.md §3.7](./LENDING_PROTOCOL.md#37-liquidationengine) |

**Authoritative status:** [LENDING_PROTOCOL.md](./LENDING_PROTOCOL.md) for protocol-wide state; this file for module phase detail.

---

*Document version: Phases 1–3 aligned with `LiquidationEngine.sol`. Phases 4–6 and full Lending integration are roadmap items.*
