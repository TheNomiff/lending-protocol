# Today Motive

**Client**: Nomiff Labs

**Project**:
Nomiff Lending Protocol

**Current Sprint**:
Protocol Hardening Sprint

**Goal**: 
Increase confidence in protocol before adding new architecture.

# Sprint 1 — RiskEngine Validation

**Objective**
- Prove that RiskEngine behaves correctly under all expected conditions.

## Task 1 — Finish RiskEngine Unit tests

| Module | Capability | Status |
| :--- | :--- | :---: |
| **Risk Engine** | Constructor validation | ✅ |
| **Risk Engine** | Health factor calculations | ✅ |
| **Risk Engine** | Borrow & withdraw validation | ✅ |
| **Risk Engine** | Liquidation eligibility & close factor | ✅ |
| **Risk Engine** | Liquidation bonus | ✅ |
| **Risk Engine** | Unit test suite | ✅ |
| **Risk Engine** | Supply & borrow caps | 🟡 |
| **Risk Engine** | Guardian emergency pause | 🟡 |
| **Risk Engine** | Owner parameter updates | 🟡 |
| **Risk Engine** | Fuzz tests | 🟡 |
| **Risk Engine** | Invariant tests | 🟡 |

**Remaining:**

**Owner Tests**
- testOwnerCanUpdateMaxBorrowRatio()
- testOwnerCanUpdateLiquidationThreshold()
- testOwnerCanUpdateCloseFactor()
- testOwnerCanUpdateLiquidationBonus()

- testNonOwnerCannotUpdateMaxBorrowRatio()
- testNonOwnerCannotUpdateThreshold()
- testNonOwnerCannotUpdateCloseFactor()
- testNonOwnerCannotUpdateBonus()

Purpose: Admin controls work correctly.

**Guardian Tests**
- testGuardianCanPauseBorrow()
- testGuardianCanPauseDeposit()
- testGuardianCanPauseLiquidation()

- testNonGuardianCannotPauseBorrow()
- testNonGuardianCannotPauseDeposit()

Purpose: Emergency controls work.

**Cap Tests**
- testCanSupplyAtCap()
- testCanSupplyAboveCap()

- testCanBorrowAtCap()
- testCanBorrowAboveCap()

Purpose: Risk limits cannot be exceeded.

# Spirit 2 — Oracle Validation
After RiskEngine.

**Objective**

Ensure protocol never uses bad pricing.

Create: 
- testGetPrice()
- testRevertOnZeroPrice()
- testRevertOnNegativePrice()
- testRevertOnStalePrice()
- testPause()
- testUnpause()
- testTransferOwnership()
- testSetPriceFeed()

# Spirit 3 — Fuzz Testing
After Oracle.

Create:
- RiskEngineFuzz.t.sol

Examples:

- maxBorrowRatio < liquidationThreshold
- supplyCap never exceeded
- borrowCap never exceeded
- HF never negative
 
# Sprint 5 — Architecture Expansion
Only after all pervious work.

Start:
- LiuquidationEngine.sol

Responsibilities:

- close factor
- liquidation bonus
- seized collateral
- liquidation execution

Move liquidation logic out of Lending.sol.