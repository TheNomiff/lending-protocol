# PriceOracle — Architecture Blueprint

> **Status:** ✅ Phase 1 complete and tested. Phases 2–6 ⬜ planned.
>
> **Protocol phase:** [LENDING_PROTOCOL.md](./LENDING_PROTOCOL.md) Phase 3 — Oracle (Phase 1 deliverable complete).
>
> **Scope:** Current architecture, future phases, security model, upgrade path, multi-asset support, testing strategy, and audit checklist. No implementation code.
>
> **Last synchronized:** June 2026 · see [LENDING_PROTOCOL.md §13](./LENDING_PROTOCOL.md#13-document-maintenance).

---

## Table of Contents

1. [Overview](#1-overview)
2. [Current Architecture](#2-current-architecture)
3. [Current Features (Phase 1)](#3-current-features-phase-1)
4. [Oracle Security Model](#4-oracle-security-model)
5. [Phase 2 (Multi-Asset Oracle)](#5-phase-2-multi-asset-oracle)
6. [Phase 3 (Portfolio Valuation Layer)](#6-phase-3-portfolio-valuation-layer)
7. [Phase 4 (Oracle Aggregation Layer)](#7-phase-4-oracle-aggregation-layer)
8. [Phase 5 (Circuit Breakers)](#8-phase-5-circuit-breakers)
9. [Phase 6 (Institutional Oracle Architecture)](#9-phase-6-institutional-oracle-architecture)
10. [Oracle Integration With Other Modules](#10-oracle-integration-with-other-modules)
11. [Testing Strategy](#11-testing-strategy)
12. [Security Checklist](#12-security-checklist)
13. [Long-Term Vision](#13-long-term-vision)

---

## 1. Overview

### What Is an Oracle?

An **oracle** is a bridge between off-chain reality and on-chain state. Blockchains are deterministic, closed systems: smart contracts can only read data that exists inside the chain or that is explicitly injected into a transaction. Asset prices, interest rates, weather data, and sports scores all live off-chain. An oracle publishes that external information on-chain in a format contracts can consume.

In this protocol, `PriceOracle.sol` is the dedicated **price integrity module**. It reads ETH/USD market data from Chainlink, validates it, and exposes normalized pricing functions that downstream modules use for collateral valuation, borrow limits, withdrawal safety, and liquidation eligibility.

### Why Smart Contracts Cannot Access Off-Chain Data Directly

The EVM has no native mechanism to:

- Query HTTP APIs or WebSocket feeds.
- Read exchange order books or index prices.
- Trust arbitrary calldata supplied by users without verification.

Any price a user submits in a transaction could be fabricated. If `Lending.sol` accepted a user-provided ETH price, a borrower could claim ETH is worth $1,000,000, borrow the entire liquidity pool, and default. On-chain systems therefore require a **trusted, validated, externally sourced price feed** with integrity checks at the point of consumption.

Oracles solve this by having specialized infrastructure (Chainlink nodes, Pyth publishers, etc.) aggregate off-chain data and write it to on-chain aggregator contracts. `PriceOracle` wraps those aggregators with protocol-specific validation.

### Why Lending Protocols Depend on Accurate Pricing

Lending protocols are **collateralized credit markets**. Users deposit assets, borrow against them, and remain solvent only while collateral value exceeds debt value (after risk haircuts). Every solvency decision reduces to a comparison of two numbers denominated in a common unit — typically USD.

Inaccurate pricing causes:

| Failure Mode | Consequence |
| :--- | :--- |
| **Overpriced collateral** | Users borrow more than their position warrants → bad debt when price corrects |
| **Underpriced collateral** | Unfair liquidations; users lose collateral despite being solvent |
| **Stale prices** | Positions appear healthy during market crashes; protocol accumulates bad debt |
| **Zero/negative prices** | Division errors, free borrows, or total protocol insolvency |

Pricing is not a UX convenience. It is the **primary economic security boundary** of the protocol.

### Why PriceOracle Is a Critical Security Component

`PriceOracle` sits at the foundation of the risk stack. If it fails, every module above it fails simultaneously:

```
Chainlink Feed
      ↓
PriceOracle          ← single point of price truth (Phase 1)
      ↓
Lending.sol          ← converts ETH balances to USD for all risk checks
      ↓
RiskEngine           ← health factor, borrow/withdraw validation
      ↓
LiquidationEngine    ← seizure amounts (same-asset ETH today; oracle-dependent in multi-asset)
```

A compromised or stale oracle does not merely misprice one transaction — it misprices **every** borrow, withdraw, and liquidation check in the same block.

### Module Dependencies

#### RiskEngine Dependency

`RiskEngine` does **not** call `PriceOracle` directly. It receives pre-computed USD values from `Lending.sol`:

- `collateralUsd` — USD value of deposited ETH
- `debtUsd` — USD value of outstanding debt (including accrued interest)

`RiskEngine` applies risk parameters (`maxBorrowRatio`, `liquidationThreshold`, `minHealthFactor`) to these USD-denominated inputs. The oracle's accuracy directly determines whether `canBorrow()`, `canWithdraw()`, and `isLiquidatable()` produce correct results.

#### LiquidationEngine Dependency

In Phase 1, collateral and debt are both ETH. Liquidation seizure math operates in native ETH units (`repayAmount + bonus`), so `LiquidationEngine` does not call the oracle. However, **liquidation eligibility** still depends on oracle-derived USD values: `Lending._healthFactor()` converts ETH balances to USD before calling `RiskEngine.healthFactor()` and `RiskEngine.isLiquidatable()`.

In multi-asset phases (Phase 2+), `LiquidationEngine` will require oracle prices to convert repayment in one asset into seizure of another (e.g., repay USDC debt, seize WBTC collateral).

#### Lending Dependency

`Lending.sol` is the **primary oracle consumer**. It calls `oracle.getETHValueInUSD()` in:

| Function | Oracle Usage |
| :--- | :--- |
| `borrow()` | Collateral USD, new borrow USD, total debt USD → `canBorrow()` |
| `withdraw()` | Remaining collateral USD, debt USD → `canWithdraw()` |
| `_healthFactor()` | Collateral USD, debt USD → `healthFactor()` |
| `liquidate()` | Indirect via `_healthFactor()` and `_revertIfHealthy()` |

Every user-facing state transition that affects solvency passes through the oracle.

---

## 2. Current Architecture

### Protocol Topology

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
                    │  (calls oracle for USD conversion)  │
                    └──────────┬────────────┬─────────────┘
                               │            │
              USD values       │            │  liquidation math (ETH units)
                               ▼            ▼
              ┌────────────────────┐   ┌─────────────────────┐
              │   RiskEngine.sol   │   │ LiquidationEngine   │
              │  HF · caps · pause │   │ closeFactor · bonus │
              │  (no direct oracle)│   │ (no direct oracle)  │
              └────────────────────┘   └─────────────────────┘
                        ▲
                        │ collateralUsd, debtUsd
                        │
              ┌────────────────────┐
              │  PriceOracle.sol   │
              │  getPrice()          │
              │  getETHValueInUSD()  │
              └─────────┬──────────┘
                        │
                        ▼
              ┌────────────────────┐
              │  Chainlink Feed    │
              │  AggregatorV3      │
              │  (ETH/USD)         │
              └────────────────────┘

              ┌────────────────────┐
              │   Timelock.sol     │  (planned: owner of PriceOracle
              │   delayed exec     │   admin functions)
              └────────────────────┘
```

### Price Read Flow

```
┌──────────────┐     latestRoundData()      ┌──────────────────┐
│  Chainlink   │ ─────────────────────────► │   PriceOracle    │
│  Aggregator  │   returns (roundId, price, │                  │
│  (ETH/USD)   │   startedAt, updatedAt,    │  1. notPaused    │
└──────────────┘   answeredInRound)         │  2. price > 0    │
                                             │  3. freshness    │
                                             │  4. return price │
                                             └────────┬─────────┘
                                                      │
                              getETHValueInUSD(ethAmount)
                                                      │
                                                      ▼
                                             ┌──────────────────┐
                                             │   Lending.sol    │
                                             │  borrow/withdraw │
                                             │  healthFactor    │
                                             └──────────────────┘
```

### Chainlink Aggregator Usage

`PriceOracle` stores a single `AggregatorV3Interface` reference (`priceFeed`) set at deployment or updated via `setPriceFeed()`.

The contract calls `priceFeed.latestRoundData()`, which returns five values:

| Index | Field | Used by PriceOracle |
| :--- | :--- | :--- |
| 0 | `roundId` | Not used (Phase 1) |
| 1 | `answer` (price) | **Yes** — cast to `uint256` after validation |
| 2 | `startedAt` | Not used (Phase 1) |
| 3 | `updatedAt` | **Yes** — stale time check |
| 4 | `answeredInRound` | Not used (Phase 1) |

Phase 1 intentionally uses a minimal subset of Chainlink return data. Future phases should validate `answeredInRound >= roundId` and monitor round completeness for production deployments.

### Stale Checks

After reading `updatedAt` from the feed:

```
if (block.timestamp - updatedAt > staleTime) → revert PriceOracle__StalePrice
```

Default `staleTime = 1 hours`. This is configurable by the owner via `setStaleTime()`.

The stale check ensures the protocol never acts on prices that Chainlink nodes have not recently updated — protecting against oracle outages, network congestion, or feed deprecation.

### Pause System

`PriceOracle` maintains a global `paused` flag:

| Function | Behavior when paused |
| :--- | :--- |
| `getPrice()` | Reverts `PriceOracle__Paused` |
| `getETHValueInUSD()` | Reverts (calls `getPrice()` internally) |
| `getUSDToETH()` | Reverts (calls `getPrice()` internally) |
| Admin functions (`pause`, `unpause`, `setStaleTime`, etc.) | Still callable by owner |

Pausing the oracle **freezes all solvency-dependent operations** in `Lending.sol` because every risk check calls `getETHValueInUSD()`. Deposits and repays may still succeed depending on their code paths, but borrows, withdrawals, and liquidations that require pricing will revert.

This is a deliberate **fail-closed** design: unknown price is safer than stale or manipulated price.

### Ownership Model

| Property | Phase 1 Value |
| :--- | :--- |
| Owner | Set to `msg.sender` at deployment |
| Privileged functions | `pause`, `unpause`, `setStaleTime`, `setPriceFeed`, `transferOwnership` |
| Access control | `onlyOwner` modifier on all admin functions |
| Timelock integration | **Planned** — ownership should transfer to `Timelock.sol` for delayed execution of feed changes and parameter updates |

Current test infrastructure (`TimelockTestBase`, `LendingTestBase`) demonstrates queuing `PriceOracle` admin calls through Timelock. Production deployment should follow the same pattern before mainnet launch.

### Feed Updates

The owner can replace the Chainlink aggregator via `setPriceFeed(address newFeed)`:

- Validates `newFeed != address(0)`.
- Emits `FeedUpdated(oldFeed, newFeed)`.
- Takes effect immediately on the next `getPrice()` call.

**Risk:** Immediate feed replacement without timelock allows a malicious or compromised owner to point the oracle at a fake aggregator and drain the protocol. Mitigation: Timelock ownership + community review period before execution.

---

## 3. Current Features (Phase 1)

### Implemented Functionality

| Function | Visibility | Description |
| :--- | :--- | :--- |
| `getPrice()` | public view | Returns validated ETH/USD price from Chainlink |
| `getETHValueInUSD(uint256 ethAmount)` | public view | Converts ETH (wei) to USD-denominated value |
| `getUSDToETH(uint256 usdAmount)` | public view | Converts USD-denominated value to ETH (wei) |
| `pause()` | external | Owner halts all price reads |
| `unpause()` | external | Owner resumes price reads |
| `setStaleTime(uint256)` | external | Owner updates staleness threshold |
| `setPriceFeed(address)` | external | Owner replaces Chainlink aggregator |
| `transferOwnership(address)` | external | Owner transfers admin control |

### Constants and State

| Name | Value / Type | Purpose |
| :--- | :--- | :--- |
| `FEED_PRECISION` | `1e8` (constant) | Chainlink USD feed decimal normalization |
| `staleTime` | `1 hours` (default, mutable) | Maximum age of acceptable price data |
| `priceFeed` | `AggregatorV3Interface` | Active Chainlink ETH/USD aggregator |
| `owner` | `address` | Admin authority |
| `paused` | `bool` | Global kill switch |

### Formula: USD Value

Converts an ETH amount (18 decimals) to a USD-denominated value using the Chainlink price (8 decimals):

```
usdValue = (ethAmount × price) / FEED_PRECISION
```

**Example:** ETH price = `2000e8`, ethAmount = `10 ether` (10 × 10¹⁸ wei)

```
usdValue = (10 × 10¹⁸ × 2000 × 10⁸) / 10⁸
         = 10 × 10¹⁸ × 2000
         = 20_000 × 10¹⁸
         = 20_000 ether   (internal 18-decimal USD representation)
```

The protocol represents USD values in **18-decimal fixed point** internally (matching ETH wei precision), even though the Chainlink feed uses 8 decimals. This avoids precision loss when comparing collateral and debt values in `RiskEngine`.

### Formula: ETH Conversion

Converts a USD-denominated value (18 decimals) back to ETH (wei):

```
ethAmount = (usdAmount × FEED_PRECISION) / price
```

**Example:** usdAmount = `20_000 ether`, price = `2000e8`

```
ethAmount = (20_000 × 10¹⁸ × 10⁸) / (2000 × 10⁸)
          = 10 × 10¹⁸
          = 10 ether
```

`getUSDToETH()` is implemented in Phase 1 but not yet consumed by `Lending.sol`. It exists for future multi-asset and portfolio valuation layers.

### Precision Handling

| Layer | Decimals | Notes |
| :--- | :--- | :--- |
| ETH amounts | 18 | Native wei, used throughout `Lending.sol` |
| Chainlink ETH/USD feed | 8 | Standard Chainlink USD pair precision |
| `FEED_PRECISION` | 8 (`1e8`) | Normalizes feed answer into calculations |
| Internal USD values | 18 | Result of `getETHValueInUSD()` — compatible with `RiskEngine.PRECISION` (1e18) |

**Overflow consideration:** `ethAmount * price` for large positions must not overflow `uint256`. At 18-decimal ETH amounts up to total supply (~120M ETH) and prices up to ~$100,000, the product remains within `uint256` bounds. Multi-asset phases must re-evaluate per-asset decimal combinations.

**Rounding:** Integer division truncates toward zero. The protocol consistently truncates in favor of protocol safety (slightly lower collateral USD, slightly higher effective debt) depending on operation direction. Document rounding direction per function when implementing multi-asset conversions.

### Stale Price Protection

Stale protection operates at read time, not at write time:

1. Every `getPrice()` call fetches fresh `updatedAt` from Chainlink.
2. Compares `block.timestamp - updatedAt` against `staleTime`.
3. Reverts if exceeded — no cached price is ever served.

This means:

- A Chainlink feed that stops updating causes all priced operations to revert after `staleTime` elapses.
- Shortening `staleTime` increases safety but increases sensitivity to Chainlink update delays.
- Lengthening `staleTime` reduces revert frequency but widens the window for acting on outdated prices.

Default `1 hour` aligns with Chainlink heartbeat on major ETH/USD feeds (typically ~3600s on Ethereum mainnet) but should be verified per deployment network.

### Invalid Price Protection

```
if (price <= 0) revert PriceOracle__InvalidPrice
```

Rejects:

- Zero price (would cause division-by-zero in `getUSDToETH()`).
- Negative price (Chainlink can return negative int256 on certain failure modes).

### Test Coverage (Phase 1)

Existing test suites under `test/unit/oracle/`:

| Test File | Coverage |
| :--- | :--- |
| `PriceOracleConstructor.t.sol` | Zero feed rejection |
| `PriceOraclePrice.t.sol` | Correct price, zero/negative/stale reverts |
| `PriceOracleConversion.t.sol` | ETH↔USD conversions, price update propagation |
| `PriceOracleStaleTime.t.sol` | Owner stale time updates, stale revert |
| `PriceOraclePause.t.sol` | Pause/unpause, paused revert on reads |
| `PriceOracleFeed.t.sol` | Feed replacement, access control |
| `PriceOracleOwnership.t.sol` | Ownership transfer, zero address rejection |
| `PriceOracleEdgeCases.t.sol` | Boundary amounts, price changes |

---

## 4. Oracle Security Model

### Threat Landscape

#### Stale Data

**Threat:** Chainlink nodes stop updating due to network congestion, feed deprecation, or oracle network failure. The last published price remains on-chain but no longer reflects market reality.

**Impact:** During a market crash, stale high prices allow borrowers to maintain artificially healthy positions. The protocol cannot liquidate underwater accounts.

**Mitigation (Phase 1):** `staleTime` check on every `getPrice()` read. Configurable threshold. Oracle pause for manual intervention.

#### Oracle Outages

**Threat:** Complete failure of Chainlink infrastructure or L2 sequencer issues preventing feed updates.

**Impact:** All priced operations revert after staleness threshold — protocol freeze.

**Mitigation:** Pause/unpause for controlled degradation; Phase 4+ multi-oracle fallback; Phase 5 circuit breakers; guardian-triggered RiskEngine pauses (borrow/liquidation) independent of oracle.

#### Negative Prices

**Threat:** Chainlink aggregator returns negative `int256` (documented edge case during feed malfunction).

**Impact:** Casting to `uint256` without validation would wrap to enormous positive number.

**Mitigation (Phase 1):** Explicit `price <= 0` revert before cast.

#### Zero Prices

**Threat:** Feed returns `0` (misconfiguration, attack on custom aggregator, test feed left in production).

**Impact:** `getUSDToETH()` division by zero; collateral valued at $0 → instant liquidation or borrow rejection.

**Mitigation (Phase 1):** Explicit zero check. Future phases: minimum price bounds per asset.

#### Delayed Updates

**Threat:** Price is technically "fresh" per `staleTime` but market has moved significantly since last Chainlink update (flash crash between heartbeats).

**Impact:** Temporary mispricing window; unfair borrows or missed liquidations.

**Mitigation:** Phase 5 circuit breakers (sudden drop detection); Phase 6 TWAP/median; shorter `staleTime` for volatile assets; secondary oracle cross-check (Phase 4).

#### Malicious Feed Replacement

**Threat:** Compromised owner calls `setPriceFeed()` pointing to a fake aggregator with attacker-controlled prices.

**Impact:** Total protocol drain — attackers inflate collateral value, borrow all liquidity, or avoid liquidation.

**Mitigation:** Timelock ownership with community review delay; feed address allowlist; Phase 4 multi-oracle aggregation; monitoring and alerting on `FeedUpdated` events.

### Why `staleTime` Exists

`staleTime` is the protocol's **maximum acceptable price age**. It exists because:

1. On-chain prices are snapshots, not live streams. The protocol must define when a snapshot is too old to trust.
2. Chainlink feeds update on deviation thresholds and heartbeats — there are legitimate gaps between updates.
3. Without a staleness check, `latestRoundData()` would return the last price forever, even if Chainlink abandoned the feed months ago.

The parameter balances **liveness** (protocol keeps operating) against **safety** (protocol only acts on recent data).

Recommended future enhancement: **asset-specific stale thresholds** (Phase 6). Stablecoins may tolerate longer staleness; volatile assets require shorter windows.

### Why Pause Functionality Exists

The oracle pause is an **emergency stop** distinct from stale reverts:

| Scenario | Stale Revert | Pause |
| :--- | :--- | :--- |
| Feed stops updating | Automatic after `staleTime` | — |
| Suspected manipulation | May not trigger if feed is "fresh" | Owner/guardian pauses immediately |
| Feed migration | Old feed stale, new feed not yet set | Pause during transition |
| Incident response | Passive | Active, immediate, intentional |

Pause allows governance to **proactively halt** pricing before damage occurs, rather than waiting for staleness math to catch up.

Coordination with `RiskEngine` pause flags (`borrowPaused`, `liquidationPaused`, `depositPaused`) provides defense in depth: oracle pause stops USD conversion; RiskEngine pause stops specific operation classes.

### Timelock Ownership (Target State)

All privileged `PriceOracle` functions should eventually be owned by `Timelock.sol`:

```
Community / Multisig
        ↓
   Timelock.queue(target=PriceOracle, data=setPriceFeed(...))
        ↓
   Wait delay (e.g., 24–48 hours)
        ↓
   Timelock.execute()
        ↓
   PriceOracle.setPriceFeed(newFeed)
```

Functions requiring timelock governance:

- `setPriceFeed()` — highest risk; changes price source
- `setStaleTime()` — affects safety/liveness tradeoff
- `transferOwnership()` — meta-governance
- `pause()` / `unpause()` — emergency; may also warrant guardian role with instant execution

---

## 5. Phase 2 (Multi-Asset Oracle)

### Motivation

Phase 1 supports **ETH only**. Collateral and debt are the same asset, so USD conversion is sufficient for solvency checks. Multi-asset lending requires knowing the USD price of each supported token independently.

### Target Assets

| Asset | Feed Pair | Typical Decimals | Notes |
| :--- | :--- | :--- | :--- |
| ETH | ETH/USD | 8 | Existing Phase 1 feed |
| BTC | BTC/USD | 8 | Native BTC or wrapped |
| LINK | LINK/USD | 8 | Protocol token collateral |
| WBTC | BTC/USD or WBTC/USD | 8 | May share BTC/USD feed with scaling |
| USDC | USDC/USD | 8 | Stablecoin; tight band expected |
| DAI | DAI/USD | 8 | Stablecoin; depeg monitoring required |

### Architecture: Asset → Feed Mapping

```
┌─────────────────────────────────────────────────────────┐
│                    PriceOracle V2                        │
│                                                          │
│  mapping(address asset => AggregatorV3Interface feed)    │
│  mapping(address asset => uint256 staleTime)   [Phase 6] │
│  mapping(address asset => bool enabled)                  │
│                                                          │
│  getPrice(address asset) → uint256                       │
│  getAssetValue(address asset, uint256 amount) → uint256  │
└──────────────────────────┬──────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
   ┌──────────┐     ┌──────────┐     ┌──────────┐
   │ ETH/USD  │     │ BTC/USD  │     │ USDC/USD │
   │ Chainlink│     │ Chainlink│     │ Chainlink│
   └──────────┘     └──────────┘     └──────────┘
```

### Feed Registration

New admin functions (conceptual):

| Function | Purpose |
| :--- | :--- |
| `addAsset(address asset, address feed)` | Register new asset with Chainlink feed |
| `removeAsset(address asset)` | Disable pricing for delisted asset |
| `setAssetFeed(address asset, address newFeed)` | Replace feed for existing asset |
| `setAssetStaleTime(address asset, uint256)` | Per-asset staleness (Phase 6) |

Registration validation requirements:

1. `asset != address(0)` and `feed != address(0)`.
2. Feed decimals documented and handled (`FEED_PRECISION` may become per-feed or normalized to 1e18).
3. Test read succeeds and returns positive price.
4. Asset enabled flag set only after validation.
5. Timelock delay on all registration and replacement operations.

### Feed Replacement

Feed replacement is the **highest-risk oracle operation** after initial deployment.

Replacement procedure:

```
1. Governance proposal: replace USDC/USD feed
2. Queue via Timelock with 48h delay
3. Pre-execution validation:
   - New feed address verified against Chainlink official registry
   - Test getPrice(newFeed) on fork
   - Compare old vs new feed prices (within tolerance)
4. Execute setAssetFeed(USDC, newFeed)
5. Monitor events and first 100 transactions
6. Rollback plan: queue reverse replacement if price divergence detected
```

### Asset Management

Maintain an **asset registry** (may live in `PriceOracle` or separate `AssetRegistry.sol`):

| Field | Purpose |
| :--- | :--- |
| `token address` | ERC-20 identifier |
| `decimals` | Token native decimals (6 for USDC, 8 for WBTC, 18 for ETH) |
| `feed address` | Chainlink aggregator |
| `enabled` | Whether asset is active |
| `assetType` | Collateral, borrowable, or both |
| `maxStaleTime` | Override default staleness |

`Lending.sol` multi-asset evolution depends on this registry to iterate user collateral and debt positions.

### Backward Compatibility

During migration from Phase 1 to Phase 2:

- `getPrice()` (no args) delegates to `getPrice(ETH)` for existing integrations.
- `getETHValueInUSD()` delegates to `getAssetValue(WETH, ethAmount)`.
- Existing tests continue passing with ETH-only path preserved.

---

## 6. Phase 3 (Portfolio Valuation Layer)

### Motivation

Phase 2 provides per-asset prices. Phase 3 aggregates them into **position-level valuations** that `Lending.sol` and `RiskEngine` consume directly, removing duplicated conversion logic from the core ledger.

### Target Functions

#### `getAssetValue(address asset, uint256 amount) → uint256`

Single-asset USD conversion with correct decimal normalization:

```
assetValueUsd = (amount × price × 10^(18 - feedDecimals - tokenDecimals)) / normalization
```

Exact normalization formula must account for token decimals (e.g., USDC 6) and feed decimals (8) to produce 18-decimal USD output consistent with Phase 1.

#### `getPortfolioValue(address[] assets, uint256[] amounts) → uint256`

Sum of individual asset values:

```
portfolioValue = Σ getAssetValue(assets[i], amounts[i])
```

Used for multi-collateral positions where a user deposits ETH + WBTC + LINK.

#### `getCollateralValue(address user) → uint256`

Reads user collateral balances from `Lending.sol` (or receives them as parameters) and returns total risk-adjusted or gross USD collateral value.

Conceptual:

```
collateralValue = Σ getAssetValue(collateralAsset[i], userBalance[i])
```

Integration option: `Lending` passes balances to oracle view functions to avoid circular dependency.

#### `getDebtValue(address user) → uint256`

Total USD value of outstanding borrows across all debt assets:

```
debtValue = Σ getAssetValue(debtAsset[j], userDebt[j])
```

Includes accrued interest converted to debt asset units before pricing.

### Usage by Lending and RiskEngine

**Current flow (Phase 1):**

```
Lending: collateralUsd = oracle.getETHValueInUSD(user.deposited)
Lending: debtUsd = oracle.getETHValueInUSD(debt)
RiskEngine: healthFactor(collateralUsd, debtUsd)
```

**Target flow (Phase 3):**

```
Lending: collateralUsd = oracle.getCollateralValue(user)
Lending: debtUsd = oracle.getDebtValue(user)
RiskEngine: healthFactor(collateralUsd, debtUsd)   // unchanged interface
```

Benefits:

- `Lending.sol` no longer knows conversion formulas.
- Decimal normalization centralized in oracle.
- Multi-asset collateral/debt handled uniformly.
- Easier to test portfolio edge cases in isolation.

### Conceptual Health Factor Pipeline

```
User Position (multi-asset)
        ↓
PriceOracle.getCollateralValue(user)  →  collateralUsd
PriceOracle.getDebtValue(user)        →  debtUsd
        ↓
RiskEngine.healthFactor(collateralUsd, debtUsd)
        ↓
RiskEngine.isLiquidatable(HF)
```

---

## 7. Phase 4 (Oracle Aggregation Layer)

### Motivation

Phase 1–3 rely on a **single Chainlink feed per asset**. Single-oracle dependency creates:

| Risk | Description |
| :--- | :--- |
| Single point of failure | Chainlink outage = protocol freeze or stale prices |
| Oracle manipulation | Compromised feed (especially L2 sequencers) |
| Pricing disagreement | No way to detect anomalous single-feed readings |
| Vendor lock-in | Cannot switch or combine providers without contract upgrade |

Phase 4 introduces **multi-source aggregation** within `PriceOracle`.

### Architecture

```
                    ┌─────────────────────────────────┐
                    │     Oracle Aggregation Layer     │
                    │                                  │
                    │  Per asset:                      │
                    │  ┌─────────┐ ┌──────┐ ┌────────┐│
                    │  │Chainlink│ │ Pyth │ │RedStone││
                    │  └────┬────┘ └──┬───┘ └───┬────┘│
                    │       └──────────┼─────────┘      │
                    │                  ▼                │
                    │         Aggregation Engine        │
                    │    (median / weighted / fallback) │
                    │                  │                │
                    │                  ▼                │
                    │         Validated Price Output    │
                    └─────────────────────────────────┘
```

### Supported Providers (Conceptual)

| Provider | Model | Strengths |
| :--- | :--- | :--- |
| **Chainlink** | Pull-based aggregator (current) | Battle-tested; wide asset coverage |
| **Pyth** | Pull-based; high-frequency updates | Low-latency; popular on L2s |
| **RedStone** | Calldata / on-demand | Gas-efficient; many assets |

### Median Pricing

Collect price from N oracles, sort, return middle value:

```
prices = [chainlinkPrice, pythPrice, redstonePrice]
sorted = sort(prices)
medianPrice = sorted[N/2]
```

**Advantages:**

- Robust to single outlier (one manipulated feed).
- Simple to implement and audit.

**Disadvantages:**

- Requires ≥3 sources for meaningful outlier rejection.
- Even number of sources needs tie-breaking policy.

### Weighted Pricing

Assign governance-configured weights per source:

```
weightedPrice = (w1×p1 + w2×p2 + w3×p3) / (w1 + w2 + w3)
```

**Advantages:**

- Can favor more reliable sources (e.g., Chainlink weight 50%, others 25% each).

**Disadvantages:**

- Weights become governance attack surface.
- Weighted mean is NOT outlier-resistant unless combined with bounds.

Recommended: **weighted median** or **trimmed mean** (drop highest and lowest) for production.

### Oracle Disagreement Detection

Before returning a price, compare sources:

```
spread = (maxPrice - minPrice) / medianPrice
```

| Spread | Action |
| :--- | :--- |
| < 1% | Normal — return aggregated price |
| 1–5% | Emit warning event; return median; flag for monitoring |
| > 5% | Revert or trigger circuit breaker (Phase 5) |
| Any source stale | Exclude from aggregation; revert if remaining sources < minimum |

Disagreement detection protects against:

- Partial oracle failures (one feed stuck, others updating).
- Flash manipulation on a single source.
- Stablecoin depeg (USDC feeds diverge from $1).

### Why Single Oracle Is Dangerous

Historical and theoretical failures:

- **Compound v2 DAI oracle incident** — incorrect price led to bad debt.
- **Venus BNB flash loan** — oracle manipulation on less liquid assets.
- **Mango Markets** — low-liquidity oracle manipulation.

A lending protocol holding hundreds of millions in TVL cannot treat a single feed as infallible. Aggregation adds **Byzantine fault tolerance** at the cost of gas and complexity.

---

## 8. Phase 5 (Circuit Breakers)

### Motivation

Even accurate, fresh, aggregated prices may change too rapidly for the protocol to absorb safely. Circuit breakers add **rate-of-change and anomaly protections** independent of individual feed staleness.

### Trigger Conditions

#### Sudden 30% Price Drop

Detect rapid depreciation between consecutive reads or against a rolling reference:

```
dropPercent = (previousPrice - currentPrice) / previousPrice

if dropPercent > maxDropThreshold (e.g., 30%) → trigger breaker
```

**Use case:** Flash crash, exploit-induced depeg, oracle manipulation attempt. Protocol pauses borrows against the affected asset and may accelerate liquidations with capped close factor.

Reference price options:

- Previous block price (simple; chain-aware).
- 1-hour TWAP (Phase 6).
- Last governance-approved anchor.

#### Oracle Freeze

All aggregated sources stop updating simultaneously (network outage, war room scenario).

```
if allSourcesStale(asset) → freezeAsset(asset)
```

**Use case:** Prevents acting on last-known prices during total oracle failure. Existing positions remain but no new borrows or withdrawals that depend on fresh pricing.

#### Oracle Disagreement

From Phase 4 spread detection:

```
if spread > disagreementThreshold → rejectOutlierPrices() or pausePriceUpdates()
```

**Use case:** One feed manipulated while others correct — exclude outlier or halt until resolved.

### Target Functions (Conceptual)

| Function | Purpose |
| :--- | :--- |
| `pausePriceUpdates()` | Global halt on price updates; serves last safe price or reverts |
| `freezeAsset(address asset)` | Per-asset pricing halt |
| `rejectOutlierPrices()` | Remove feeds deviating beyond threshold from aggregation |
| `setMaxDropThreshold(address asset, uint256)` | Configure circuit breaker sensitivity |
| `resetCircuitBreaker(address asset)` | Governance clears breaker after incident resolution |

### Operational Flow

```
Normal Operation
      │
      ▼
Price Read Request
      │
      ├── Spread check (Phase 4)
      ├── Drop check (Phase 5)
      └── Staleness check (Phase 1)
      │
      ├── All pass → return price
      │
      └── Breaker triggered
              │
              ├── Auto: freezeAsset + emit event
              ├── Auto: RiskEngine.borrowPaused(asset)
              ├── Guardian: confirm or escalate
              └── Governance: reset after review
```

### Use Cases Summary

| Scenario | Breaker | Protocol Response |
| :--- | :--- | :--- |
| ETH -40% in 10 minutes | Drop breaker | Pause new borrows; allow liquidations |
| Chainlink + Pyth disagree 8% | Disagreement | Exclude outlier; if unresolved, freeze |
| All feeds stale 2 hours | Freeze | Halt priced operations; guardian alert |
| USDC depegs to $0.85 | Drop + disagreement | Freeze USDC borrows; tighten liquidations |

---

## 9. Phase 6 (Institutional Oracle Architecture)

### Target: Production-Grade Oracle System

Phase 6 consolidates Phases 1–5 into an institutional-quality oracle layer suitable for mainnet TVL, external integrations, and professional auditor review.

### TWAP Pricing

**Time-Weighted Average Price** smooths short-term manipulation:

```
TWAP = Σ(price_i × duration_i) / totalDuration
```

Implementation options:

- On-chain ring buffer of historical prices (gas-intensive).
- Oracle-provided TWAP (Chainlink Automation, Pyth EMA).
- Off-chain keeper submits TWAP with on-chain verification.

**Use for:** Collateral valuation on borrow/withdraw (conservative). **Spot price** for liquidations (timely) — dual-price model aligned with Aave v3 practice.

### Median Pricing

Permanent integration of Phase 4 median aggregation as default production mode with minimum three independent sources per asset.

### Oracle Fallback Hierarchy

Ordered fallback when primary sources fail:

```
Priority 1: Aggregated median (Chainlink + Pyth + RedStone)
     ↓ failure
Priority 2: Chainlink alone (if fresh)
     ↓ failure
Priority 3: Secondary oracle alone (if fresh)
     ↓ failure
Priority 4: Circuit breaker → revert (fail closed)
```

Never fall back to user-supplied or admin-set manual prices without timelock and explicit emergency governance.

### Asset-Specific Stale Thresholds

| Asset Class | Recommended Stale Time | Rationale |
| :--- | :--- | :--- |
| ETH, BTC | 1 hour | Standard Chainlink heartbeat |
| Large-cap alts (LINK) | 1–2 hours | Moderate volatility |
| Stablecoins (USDC, DAI) | 24–48 hours | Tight band; slower updates acceptable |
| Long-tail assets | Not supported or ≤30 min | High manipulation risk |

### Historical Pricing Support

Store price snapshots for:

- Incident forensics (what price was used at liquidation block N).
- TWAP computation.
- Governance post-mortems.

Options:

- `PriceSnapshot` events on every significant price change.
- Circular on-chain buffer (last N prices per asset).
- Off-chain indexer (subgraph) with on-chain event sourcing.

Liquidation disputes and insurance claims require provable historical pricing.

### Conceptual Comparison: Aave, Compound, Morpho

#### Aave Oracle System

| Aspect | Aave Approach | This Protocol (Target) |
| :--- | :--- | :--- |
| Architecture | `AaveOracle` with asset → source mapping | `PriceOracle` Phases 2–6 equivalent |
| Sources | Chainlink primary; fallback oracle | Multi-source aggregation (Phase 4) |
| Pricing model | Base currency (USD) with unit conversion | 18-decimal USD internal standard |
| Sentinel / fallback | Fallback oracle for L2 sequencer issues | Fallback hierarchy (Phase 6) |
| Governance | Aave Governance + timelock | Timelock on all feed changes |

**Takeaway:** Aave separates oracle from pool logic — same modular principle. Their fallback oracle and sentinel concepts map directly to Phase 5–6 circuit breakers.

#### Compound Oracle Model

| Aspect | Compound Approach | This Protocol (Target) |
| :--- | :--- | :--- |
| Architecture | `CompoundOracle` / Open Price Feed | Centralized `PriceOracle` module |
| Sources | Chainlink + Uniswap TWAP (v2) | Chainlink + Pyth + RedStone (Phase 4) |
| Admin | Governance via Governor | Timelock |
| Simplicity | Per-market price anchor | Per-asset feed registry (Phase 2) |

**Takeaway:** Compound demonstrated TWAP complement to spot oracles — validates Phase 6 dual-price design.

#### Morpho Oracle Design

| Aspect | Morpho Approach | This Protocol (Target) |
| :--- | :--- | :--- |
| Architecture | Morpho Blue: immutable markets with external oracle contract | Modular engines with upgradeable oracle |
| Flexibility | Market creator chooses oracle | Governance-curated asset list |
| Isolation | Per-market oracle address | Per-asset feed with protocol-wide registry |
| Efficiency | Minimal on-chain logic | Aggregation adds gas; batch reads mitigate |

**Takeaway:** Morpho treats oracle as pluggable dependency — `PriceOracle` must expose a clean, stable interface (`getAssetValue`) for external market creators in future protocol versions.

---

## 10. Oracle Integration With Other Modules

### Responsibility Matrix

| Module | Calls PriceOracle? | Provides to PriceOracle? | Responsibility |
| :--- | :--- | :--- | :--- |
| **PriceOracle** | — | Prices to all consumers | Price validation, conversion, aggregation |
| **Lending** | Yes — `getETHValueInUSD()` | User balances (Phase 3+) | Accounting; converts balances via oracle |
| **RiskEngine** | No (Phase 1) | — | Applies risk params to USD values from Lending |
| **LiquidationEngine** | No (Phase 1) | — | Seizure math; oracle needed Phase 4+ multi-asset |
| **Timelock** | No | Executes admin calls | Delayed governance over oracle parameters |

### PriceOracle ↔ Lending

**Direction:** Lending → PriceOracle (read-only)

**Phase 1 integration points in `Lending.sol`:**

| Call Site | Purpose |
| :--- | :--- |
| `borrow()` | `getETHValueInUSD(deposited)`, `getETHValueInUSD(amount)`, `getETHValueInUSD(totalDebt)` |
| `withdraw()` | `getETHValueInUSD(remainingCollateral)`, `getETHValueInUSD(debt)` |
| `_healthFactor()` | `getETHValueInUSD(deposited)`, `getETHValueInUSD(debt + interest)` |

**Contract:** Lending treats oracle as **single source of USD truth**. Lending must never perform its own price fetching or decimal math.

**Failure behavior:** Any oracle revert (stale, paused, invalid) propagates to user transaction revert. Lending does not catch and suppress oracle errors.

**Future:** Lending holds `PriceOracle public oracle` — upgradeable via governance to new oracle contract address with migration procedure.

### PriceOracle ↔ RiskEngine

**Direction:** Indirect — Lending converts, RiskEngine validates

**Phase 1:**

```
Lending computes USD → RiskEngine.healthFactor(collateralUsd, debtUsd)
                    → RiskEngine.canBorrow(collateralUsd, totalDebtUsd)
                    → RiskEngine.canWithdraw(remainingCollateralUsd, debtUsd)
                    → RiskEngine.isLiquidatable(healthFactor)
```

RiskEngine comments note: *"V3 assumes debt asset and collateral asset are same asset (ETH). Multi-asset version must convert through oracle prices."*

**Future (Phase 3):** RiskEngine interface unchanged. Oracle may expose portfolio functions that Lending calls before RiskEngine validation.

**Separation rationale:** RiskEngine stays pure — ratios and thresholds only. Oracle stays pure — pricing only. Lending orchestrates.

### PriceOracle ↔ LiquidationEngine

**Direction:** No direct calls (Phase 1)

**Phase 1 liquidation path:**

```
Lending.liquidate()
  → oracle (via _healthFactor) → RiskEngine.isLiquidatable()
  → LiquidationEngine.calculateSeizedCollateral(repayAmount)   // ETH units
```

Because collateral = debt = ETH, seizure math is 1:1 plus bonus in native units. Oracle affects **eligibility**, not **seizure quantity**.

**Future (Phase 4+ multi-asset):**

```
seizeAmount = (repayUsd × (1 + bonus)) / collateralPriceUsd
```

LiquidationEngine will consume oracle prices for cross-asset conversion. PriceOracle must provide `getAssetValue()` with consistent decimals.

### PriceOracle ↔ Timelock

**Direction:** Timelock → PriceOracle (admin execution)

**Target ownership model:**

```
PriceOracle.owner = Timelock.address
```

**Queued operations:**

| Target Function | Risk Level | Recommended Delay |
| :--- | :--- | :--- |
| `setPriceFeed()` | Critical | 48 hours |
| `setStaleTime()` | High | 24 hours |
| `addAsset()` / `setAssetFeed()` | Critical | 48 hours |
| `transferOwnership()` | Critical | 72 hours |
| `pause()` | Medium | Instant (guardian) or 0 delay |
| `unpause()` | Medium | 24 hours |

**Events for monitoring:** `FeedUpdated`, `StaleTimeUpdated`, `Paused`, `Unpaused` — all should trigger off-chain alerts.

---

## 11. Testing Strategy

### Phase 1 (Current — Complete)

#### Unit Tests

| Scenario | Expected Behavior |
| :--- | :--- |
| `getPrice()` with valid feed | Returns `2000e8` for mock feed |
| Zero price | Revert `PriceOracle__InvalidPrice` |
| Negative price | Revert `PriceOracle__InvalidPrice` |
| Stale feed (`block.timestamp - updatedAt > staleTime`) | Revert `PriceOracle__StalePrice` |
| Paused oracle | Revert `PriceOracle__Paused` on reads |
| `getETHValueInUSD(10 ether)` at $2000 | Returns `20_000 ether` (18-decimal USD) |
| `getUSDToETH(20_000 ether)` at $2000 | Returns `10 ether` |
| Non-owner calls admin functions | Revert `PriceOracle__NotOwner` |
| `setPriceFeed(address(0))` | Revert `PriceOracle__InvalidFeed` |

#### Integration Tests

| Scenario | Setup |
| :--- | :--- |
| Borrow with live oracle | `LendingTestBase` — deposit, borrow within LTV |
| Borrow reverts when oracle stale | Warp past stale time, borrow reverts |
| Withdraw blocked when HF unsafe | Price drop simulation via mock feed update |
| Liquidation eligibility | Lower price until HF < 1.0 |
| Timelock feed update | Queue `setPriceFeed`, warp, execute, verify new price |

#### Fuzz Tests

| Target | Property |
| :--- | :--- |
| `getETHValueInUSD(amount)` | `amount > 0 → result > 0` (valid price) |
| Round-trip | `getUSDToETH(getETHValueInUSD(x)) ≈ x` within rounding |
| `setStaleTime(x)` | Stale revert occurs iff `block.timestamp - updatedAt > x` |

#### Invariant Tests

| Invariant | Description |
| :--- | :--- |
| Price consistency | Same block, same price across multiple `getPrice()` calls |
| Monotonic ETH value | Higher `ethAmount` → higher USD value (fixed price) |
| Pause blocks all reads | If `paused`, no code path returns price |

---

### Phase 2 (Multi-Asset)

#### Unit Tests

- Register asset with valid feed → `getPrice(asset)` returns correct value.
- Unregistered asset → revert.
- USDC (6 decimals) conversion produces correct 18-decimal USD.
- WBTC (8 decimals) conversion produces correct 18-decimal USD.
- `removeAsset()` → subsequent reads revert.

#### Integration Tests

- Deposit ETH + WBTC; total collateral USD matches manual calculation.
- Borrow USDC against multi-collateral; LTV correct.
- Feed replacement for one asset does not affect other assets.

#### Fuzz Tests

- Random asset amounts across decimal combinations.
- Register/deregister asset sequences maintain consistency.

#### Invariant Tests

- Sum of individual asset values equals portfolio value.
- Disabled asset always reverts.

---

### Phase 3 (Portfolio Valuation)

#### Unit Tests

- `getPortfolioValue()` with empty arrays → 0.
- Mismatched array lengths → revert.
- Single-user multi-asset portfolio matches sum of parts.

#### Integration Tests

- Full borrow/withdraw/HF cycle using portfolio functions only.
- Liquidation with mixed collateral composition.

#### Fuzz Tests

- Random portfolio compositions; HF monotonicity under price scaling.

#### Invariant Tests

- `getCollateralValue(user) + getDebtValue(user)` inputs produce consistent HF with RiskEngine.

---

### Phase 4 (Aggregation)

#### Unit Tests

- Three feeds agree → median equals all.
- One outlier feed → median excludes outlier effect.
- Two feeds stale → revert if below minimum sources.
- Spread > threshold → revert or flag.

#### Integration Tests

- Simulated Pyth/Chainlink divergence during borrow.
- Feed exclusion mid-aggregation.

#### Fuzz Tests

- Random prices from N sources; median always within min-max range.

#### Invariant Tests

- Aggregated price always between min and max of valid sources.
- Removing any one source changes result by ≤ max spread.

---

### Phase 5 (Circuit Breakers)

#### Unit Tests

- 30% drop triggers freeze.
- Gradual 29% drop does not trigger.
- `resetCircuitBreaker()` restores normal operation.
- Disagreement + drop compound correctly.

#### Integration Tests

- Flash crash simulation: borrow paused, liquidation still allowed.
- Guardian workflow during frozen asset.

#### Fuzz Tests

- Random price sequences; breaker triggers iff drop exceeds threshold.

#### Invariant Tests

- Frozen asset never returns new price without reset.
- Breaker state monotonic (cannot unfreeze without explicit reset).

---

### Phase 6 (Institutional)

#### Unit Tests

- TWAP over N blocks matches manual calculation.
- Fallback hierarchy selects correct source per failure mode.
- Historical snapshot retrievable for block N.

#### Integration Tests

- Full protocol operation with TWAP for borrows, spot for liquidations.
- Simulated Chainlink outage with Pyth fallback.

#### Fuzz Tests

- TWAP manipulation resistance over adversarial price sequences.

#### Invariant Tests

- TWAP deviates from spot by at most configured band under normal conditions.
- Fallback never serves stale price from lower-priority source when higher-priority is fresh.

---

## 12. Security Checklist

Auditor-focused checklist for `PriceOracle` review across all phases.

### Phase 1 (Current)

- [ ] **Stale protection:** `getPrice()` reverts when `block.timestamp - updatedAt > staleTime`
- [ ] **Invalid price rejection:** Zero and negative prices revert before `uint256` cast
- [ ] **Pause logic:** `paused == true` blocks all price reads; admin functions still accessible
- [ ] **Feed validation:** Zero address feed rejected in constructor and `setPriceFeed()`
- [ ] **Ownership security:** `onlyOwner` on all admin functions; zero address owner transfer rejected
- [ ] **Precision handling:** `FEED_PRECISION = 1e8` matches Chainlink feed decimals
- [ ] **Overflow safety:** `ethAmount * price` cannot overflow for realistic supply bounds
- [ ] **No price caching:** Every call reads fresh Chainlink data
- [ ] **Event emission:** `FeedUpdated`, `StaleTimeUpdated`, `Paused`, `Unpaused` emitted correctly
- [ ] **Reentrancy:** View functions only; no external calls beyond Chainlink aggregator
- [ ] **Aggregator interface:** Correct use of `latestRoundData()` return indices

### Phase 2+ (Future)

- [ ] **Feed registration:** New feeds validated before activation
- [ ] **Per-asset decimal handling:** Token decimals + feed decimals normalized correctly
- [ ] **Asset disable:** Disabled assets cannot be priced
- [ ] **Oracle replacement review:** Timelock delay on `setAssetFeed()` / `setPriceFeed()`
- [ ] **Timelock ownership:** No direct EOA owner in production
- [ ] **Backward compatibility:** Phase 1 ETH functions delegate correctly

### Phase 4+ (Aggregation)

- [ ] **Minimum sources:** Aggregation reverts if active sources < threshold
- [ ] **Outlier exclusion:** Manipulated single feed cannot move median beyond bounds
- [ ] **Spread limits:** Disagreement beyond threshold triggers revert or breaker
- [ ] **Stale source exclusion:** Stale feeds removed from aggregation set, not averaged in

### Phase 5+ (Circuit Breakers)

- [ ] **Drop detection:** Sudden price drop triggers expected breaker state
- [ ] **Fail-closed default:** Breaker active → revert or freeze, never silently continue
- [ ] **Reset authority:** Only governance/guardian can reset breakers
- [ ] **Cross-module coordination:** Breaker triggers appropriate RiskEngine pauses

### Phase 6 (Institutional)

- [ ] **TWAP manipulation cost:** TWAP window long enough to resist flash manipulation
- [ ] **Fallback ordering:** Priority hierarchy documented and correctly implemented
- [ ] **Dual-price policy:** TWAP vs spot usage documented per operation type
- [ ] **Historical integrity:** Snapshot storage tamper-proof and queryable

### Cross-Cutting

- [ ] **Oracle replacement review:** Any feed change requires off-chain verification against official registry
- [ ] **Monitoring:** All price anomalies emit events for off-chain alerting
- [ ] **Upgrade path:** Oracle contract upgrade does not brick Lending (migration function)
- [ ] **Documentation alignment:** Implemented behavior matches this blueprint
- [ ] **Integration tests:** End-to-end borrow/withdraw/liquidate tested with oracle failure modes

---

## 13. Long-Term Vision

### Target State (All Phases Complete)

After Phases 1–6, `PriceOracle` is the **single source of on-chain price truth** for the entire protocol:

```
┌─────────────────────────────────────────────────────────────────┐
│                      PriceOracle (Final)                         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │  Asset       │  │  Aggregation │  │  Circuit Breakers    │ │
│  │  Registry    │  │  Chainlink   │  │  Drop detection      │ │
│  │  ETH·BTC·    │  │  + Pyth      │  │  Disagreement halt   │ │
│  │  LINK·WBTC·  │  │  + RedStone  │  │  Per-asset freeze    │ │
│  │  USDC·DAI    │  │  Median/TWAP │  │  Fallback hierarchy  │ │
│  └──────────────┘  └──────────────┘  └──────────────────────┘ │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │  Valuation   │  │  Historical  │  │  Governance          │ │
│  │  getAssetVal │  │  Snapshots   │  │  Timelock-owned      │ │
│  │  getPortfolio│  │  TWAP buffer │  │  Guardian pause      │ │
│  │  getColl/Debt│  │  Audit trail │  │  Feed allowlist      │ │
│  └──────────────┘  └──────────────┘  └──────────────────────┘ │
└──────────────────────────────┬──────────────────────────────────┘
                               │
           ┌───────────────────┼───────────────────┐
           ▼                   ▼                   ▼
    ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐
    │  Lending    │    │ RiskEngine  │    │ LiquidationEng  │
    │  (ledger)   │    │ (solvency)  │    │ (cross-asset)   │
    └─────────────┘    └─────────────┘    └─────────────────┘
```

### Design Pillars

#### Reliability

- Multi-source aggregation eliminates single-vendor dependency.
- Fallback hierarchy ensures price availability degrades gracefully.
- Asset-specific staleness matches real-world update patterns.
- Circuit breakers prevent catastrophic actions during anomalies.

#### Decentralization

- Timelock-governed parameter changes with public review windows.
- No admin manual price override in normal operation.
- Transparent event emission for all price and configuration changes.
- Phase 4+ reduces trust in any single oracle operator.

#### Upgradeability

- Modular phase rollout preserves backward-compatible interfaces.
- `getETHValueInUSD()` remains valid wrapper indefinitely.
- Oracle contract replaceable via Lending governance with migration procedure.
- Asset registry supports add/remove without redeploying core protocol.

#### Auditability

- Pure view functions for all price reads.
- Historical snapshots enable post-incident analysis.
- Clear separation: PriceOracle prices, RiskEngine ratios, Lending accounting.
- Completed security checklist (Section 12) per deployment.

#### Multi-Asset Support

- Native support for major collateral and debt assets.
- Correct decimal normalization across 6–18 decimal tokens.
- Portfolio-level valuation for complex user positions.
- Cross-asset liquidation pricing in `LiquidationEngine`.

### Conceptual Comparison (Final State)

| Dimension | Aave | Compound | Morpho | This Protocol |
| :--- | :--- | :--- | :--- | :--- |
| Oracle location | External `AaveOracle` | External `CompoundOracle` | Per-market external | Dedicated `PriceOracle` module |
| Multi-source | Fallback oracle | TWAP + Chainlink | Market-chosen | Chainlink + Pyth + RedStone median |
| Governance | Aave DAO | COMP governance | Morpho DAO | Timelock |
| TWAP | Sentinel / EMA practices | Uniswap TWAP historical | External | Phase 6 on-chain TWAP |
| Multi-asset | Full | Full | Per-market | Phase 2–3 registry |
| Circuit breakers | E-mode, caps, pauses | Governance pause | Market pause | Phase 5 drop/disagreement breakers |
| Upgrade model | Governance proxy | Governance proxy | Immutable markets | Modular engine replacement |

### Success Criteria

The PriceOracle roadmap is complete when:

1. **All supported assets** (ETH, BTC, LINK, WBTC, USDC, DAI) price correctly with validated feeds.
2. **No single oracle source** can unilaterally determine protocol prices (Phase 4 live).
3. **Circuit breakers** automatically protect against flash crashes and feed disagreement.
4. **Timelock** owns all feed registration and replacement with zero EOA bypass.
5. **Lending, RiskEngine, and LiquidationEngine** consume oracle through stable portfolio/valuation APIs.
6. **Historical pricing** is available for any liquidation or borrow disputed post-incident.
7. **Auditors** sign off using the completed checklist (Section 12).
8. **Test suites** cover unit, integration, fuzz, and invariant properties for every phase.

---

## Appendix A — Phase 1 Formula Reference

```
FEED_PRECISION = 1e8

getPrice():
  (roundId, price, startedAt, updatedAt, answeredInRound) = priceFeed.latestRoundData()
  require price > 0
  require block.timestamp - updatedAt <= staleTime
  return uint256(price)

getETHValueInUSD(ethAmount):
  price = getPrice()
  return (ethAmount * price) / FEED_PRECISION

getUSDToETH(usdAmount):
  price = getPrice()
  return (usdAmount * FEED_PRECISION) / price
```

---

## Appendix B — Health Factor Dependency Chain

```
collateralUsd = oracle.getETHValueInUSD(user.deposited)
debtUsd       = oracle.getETHValueInUSD(user.borrowed + interest)

collateralAdjusted = collateralUsd × liquidationThreshold / 100
healthFactor       = collateralAdjusted × PRECISION / debtUsd

isLiquidatable     = healthFactor < minHealthFactor    (default: 1e18 = 1.0)
```

Oracle error or revert at any point → entire chain fails → user operation reverts.

---

## Appendix C — Phase Roadmap Summary

| Phase | Status | Deliverable |
| :--- | :--- | :--- |
| **1** | ✅ Complete | Single ETH/USD Chainlink feed, conversion functions, stale/pause/ownership |
| **2** | Planned | Multi-asset feed registry (`mapping(asset => feed)`) |
| **3** | Planned | Portfolio valuation (`getCollateralValue`, `getDebtValue`, `getPortfolioValue`) |
| **4** | Planned | Multi-oracle aggregation (Chainlink + Pyth + RedStone, median, disagreement detection) |
| **5** | Planned | Circuit breakers (drop detection, asset freeze, outlier rejection) |
| **6** | Planned | Institutional grade (TWAP, fallback hierarchy, per-asset staleness, historical pricing) |

---

## Appendix D — Related Documentation

| Document | Content |
| :--- | :--- |
| [LENDING_PROTOCOL.md](./LENDING_PROTOCOL.md) | Master architecture, module status, protocol roadmap |
| [RISK_ENGINE.md](./RISK_ENGINE.md) | Health factor, caps, pause, solvency framework |
| [LIQUIDATION_ENGINE.md](./LIQUIDATION_ENGINE.md) | Liquidation policy, multi-asset seizure roadmap |
| [TIMELOCK.md](./TIMELOCK.md) | Governance delay mechanics |
| [MULTI_ASSET_LENDING.md](./MULTI_ASSET_LENDING.md) | Multi-asset migration; Phase 5 oracle integration |
| [README.md](../README.md) | Repository overview |

---

## Appendix E — Document Maintenance

| When | Update |
| :--- | :--- |
| Oracle code merged | Phase 1 sections + Appendix C status table |
| Multi-asset feed added | Phase 2 sections + mark Phase 2 ✅ in Appendix C |
| Master protocol phase changes | Align Appendix C with [LENDING_PROTOCOL.md §3.4](./LENDING_PROTOCOL.md#34-priceoracle) |

**Authoritative status:** [LENDING_PROTOCOL.md](./LENDING_PROTOCOL.md) is the source of truth for protocol-wide completion; this file owns oracle-module phase detail.

---

*Document version: Phase 1 baseline — aligned with `PriceOracle.sol`. Multi-asset phases 2–6 are blueprint only until implemented.*
