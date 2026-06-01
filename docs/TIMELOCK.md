# Timelock V1

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

V2:

- Cancel queued transaction
- Custom delays
- Role system
- Batch execution
- Governance voting
- Proposal expiration