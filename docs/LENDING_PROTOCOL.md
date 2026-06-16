# LANDING Protocol

## Overview

LANDING Protocol is an ETH-collateralized lending system with time-based debt accrual and oracle-driven collateral checks.

Current implementation status:
- Core lending mechanics are implemented.
- Interest accrual is implemented.
- Foundational testing is in place (unit, fuzz, invariant baseline).
- Oracle hardening, liquidation, and later production phases are the next major milestones.

---

## Vision

Build a secure, modular, and scalable on-chain lending protocol that evolves from a single-asset MVP into a production-grade multi-asset money market with robust risk controls, automation, and audit readiness.

---

## Protocol Roadmap (Phases)

### Phase 1 - Lending (Completed)
- Deposit collateral (ETH)
- Borrow against collateral
- Withdraw collateral with safety checks
- Repay debt (including overpayment refund handling)

### Phase 2 - Interest (Completed)
- Fixed-rate debt accrual over time
- Debt tracking via principal + accrued interest
- Utility methods for debt visibility

### Phase 2.5 - Testing (Completed baseline)
- Unit tests for major user actions
- Fuzz tests for bounded input behavior
- Invariant framework initialized

### Phase 3 - Oracle (In progress / Start now)
- Oracle reliability hardening
- Pause/stale/invalid-feed behavior validation
- Stronger oracle test coverage

### Phase 4 - Liquidation
- Add liquidation mechanics for unhealthy positions
- Introduce liquidation incentive and close-factor rules
- Add liquidation-specific tests and invariants

### Phase 5 - Multi-Asset
- Move from single-asset ETH model to market-based architecture
- Per-asset risk parameters (LTV, liquidation threshold, caps)
- Tokenized collateral and debt accounting

### Phase 6 - Risk Controls
- Supply/borrow caps
- Guardian pause controls
- Parameter governance and safer admin pathways
- Reserve and protocol safety mechanisms

### Phase 7 - UI + Bots
- User-facing app for protocol interaction
- Monitoring and liquidation bots
- Alerting and operations tooling

### Phase 8 - Security
- Threat model and security documentation
- Deep invariant expansion
- Audit prep and remediation workflow

---

## How LANDING Protocol Works

### 1) Deposit
Users deposit ETH as collateral.

Effect:
- User collateral balance increases
- Protocol liquidity increases

### 2) Borrow
Users borrow ETH against their collateral based on an oracle-priced collateral limit.

Effect:
- User debt increases
- Protocol liquidity decreases
- Borrow checks enforce collateral safety before funds are sent

### 3) Interest Accrual
Debt grows over time using the configured fixed annual rate converted to per-second accrual.

Effect:
- Effective debt = principal + accrued interest
- Interest is realized when debt-related actions occur

### 4) Repay
Users repay debt in ETH.

Effect:
- User debt decreases
- Protocol liquidity increases
- Overpayment can be refunded

### 5) Withdraw
Users withdraw collateral only if post-withdraw position remains safe.

Effect:
- User collateral decreases
- Protocol liquidity decreases
- Safety checks prevent undercollateralization

---

## Core Protocol Concepts

### Collateralization
Borrowing power is derived from oracle-valued collateral and protocol thresholds.

### Health Factor
Health factor represents position safety:
- High value = safer
- Near threshold = riskier
- Critical value triggers liquidation eligibility in future phases

### Oracle Dependency
Price data drives risk decisions. Oracle correctness and freshness are critical for protocol safety.

### Liquidity Accounting
`totalLiquidity` tracks available protocol liquidity and should stay consistent with protocol balance/accounting assumptions.

---

## Important Risk Topics

### Oracle Risk
- Stale prices
- Incorrect feed configuration
- Admin misconfiguration

### Solvency Risk
- No liquidation path can lead to unresolved bad debt
- Edge-case debt growth near collateral limits

### Operational Risk
- Need stronger role separation (owner/guardian/risk admin)
- Need safer governance for sensitive parameter updates

### Security Risk
- Reentrancy and transfer path hardening
- Adversarial behavior simulations
- Formal invariant expansion

---

## Testing Strategy

Current:
- Unit tests for core user flows
- Fuzz tests for bounded random inputs
- Initial invariant tests

Target:
- Expand oracle failure-mode tests
- Add solvency and liquidation invariants
- Add adversarial contract tests
- Add coverage and release gating standards

---

## What "Completed" Means Per Phase

To avoid ambiguity, a phase is complete when:
- Feature code is implemented
- Happy + revert paths are tested
- Invariants/fuzz coverage for critical safety properties exist
- CI passes reliably
- Risks and limitations are documented

---

## Current Position (Summary)

You are at **late Phase 2.5** with a strong MVP foundation.

Recommended immediate progression:
1. Finish **Phase 3 Oracle hardening**
2. Build **Phase 4 Liquidation**
3. Introduce **Phase 6 Risk Controls (v1)** before scaling
4. Then execute **Phase 5 Multi-Asset** architecture shift

---

## Contributor Notes

When adding new features:
- Keep protocol accounting invariants explicit
- Add tests with every behavior change
- Document assumptions (oracle decimals, thresholds, rates)
- Prefer incremental, reviewable milestones over large rewrites

