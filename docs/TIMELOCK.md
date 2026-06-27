# Timelock — Governance Architecture

> **Status:** ✅ V1 complete and tested (contract + unit tests).
>
> **Protocol phase:** [LENDING_PROTOCOL.md](./LENDING_PROTOCOL.md) Phase 5 — Governance (Timelock).
>
> **Integration:** 🟡 Production ownership transfer to Timelock in progress — test fixtures already transfer Oracle/Risk ownership; mainnet sole-admin path not yet mandatory.
>
> **Last synchronized:** June 2026 · see [LENDING_PROTOCOL.md §13](./LENDING_PROTOCOL.md#13-document-maintenance).

---

## Purpose

Timelock prevents protocol owners from making instant changes to important parameters.

Without Timelock:

Owner
↓
updateMaxBorrowRatio(80)
↓
Immediately active

Risk:

Users cannot react before dangerous changes happen.


With Timelock:

Owner
↓
Queue request
↓
Wait delay period
↓
Execute request
↓
Protocol updated


---

## Contract Flow

Timelock stores pending transactions.

Structure:

```solidity
struct Queue {
    address target;
    bytes data;
    uint256 executeAfter;
    bool executed;
}
```

Meaning:

- target

Contract to call.

Example:

```solidity
RiskEngine
```

- data

Encoded function call.

Example:

```solidity
updateMaxBorrowRatio(60)
```

- executeAfter

Timestamp when transaction becomes executable.

Example:

```solidity
block.timestamp + 1 days
```

- executed

Prevents running same transaction twice.


---

## Queue Transaction Flow

Function:

```solidity
function queueTransaction(
    address target,
    bytes calldata data
)
```

Example:

Owner wants:

```solidity
updateMaxBorrowRatio(60)
```

Step 1:

Encode function:

```solidity
bytes memory data =
abi.encodeCall(
    RiskEngine
    .updateMaxBorrowRatio,
    (60)
);
```

Step 2:

Queue:

```solidity
timelock.queueTransaction(
    address(riskEngine),
    data
);
```

Stored:

Transaction #1

{
target:RiskEngine
data:updateMaxBorrowRatio(60)
executeAfter: tomorrow
executed:false
}

Nothing changes immediately.


---

## Execute Transaction Flow

Function:

```solidity
executeTransaction(
    uint256 txId
)
```

Step 1:

Load transaction:

```solidity
Queue storage txData =
queuedTransactions[txId];
```

Step 2:

Check already executed:

```solidity
if(txData.executed)
```

Prevent:

execute()
execute()
execute()

Step 3:

Check delay:

```solidity
if(
block.timestamp
<
txData.executeAfter
)
```

Prevent:

Executing before waiting period.

Step 4:

Mark executed:

```solidity
txData.executed=true;
```

Step 5:

Call target contract:

```solidity
(bool success,) =
txData.target.call(
txData.data
);
```

Example:

Automatically becomes:

```solidity
RiskEngine.updateMaxBorrowRatio(
    60
);
```


---

## Real Example

Day 1:

Queue:

```solidity
updateLiquidationThreshold(80)
```

Stored:

{
target:RiskEngine
executeAfter: tomorrow
executed:false
}

Try immediately:

```solidity
executeTransaction(1)
```

Result:

```solidity
Timelock__TooEarly()
```

Wait 24 hours:

```solidity
executeTransaction(1)
```

Result:

```solidity
RiskEngine updated
```

Transaction:

```solidity
executed=true
```

Cannot run again.


---

## Ownership Integration

Current:

You
↓
RiskEngine

After Timelock:

You
↓
Timelock
↓
RiskEngine

Transfer ownership:

```solidity
riskEngine.transferOwnership(
    address(timelock)
);
```

Now all updates must pass through Timelock.


---

## Future Improvements

V2 (see [LENDING_PROTOCOL.md §5 Phase 5+](./LENDING_PROTOCOL.md#phase-5--governance-timelock)):

- ~~Cancel queued transaction~~ ✅ V1 includes `cancelTransaction`
- Custom delays per transaction type
- Role system (proposer vs executor)
- Batch execution
- On-chain governance voting
- Proposal expiration

---

## Document Maintenance

| When | Update |
| :--- | :--- |
| Timelock code changes | Contract flow and integration sections |
| Production ownership transferred | Mark integration ✅ in header and [LENDING_PROTOCOL.md §3.6](./LENDING_PROTOCOL.md#36-timelock) |
| New admin modules added | Extend ownership integration list (Oracle, Risk, LiquidationEngine, AssetRegistry future) |

**Authoritative status:** [LENDING_PROTOCOL.md](./LENDING_PROTOCOL.md) · **Related:** [RISK_ENGINE.md](./RISK_ENGINE.md) · [PRICE_ORACLE.md](./PRICE_ORACLE.md) · [LIQUIDATION_ENGINE.md](./LIQUIDATION_ENGINE.md)