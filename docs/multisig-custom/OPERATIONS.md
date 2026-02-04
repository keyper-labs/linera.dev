# Linera Multisig Application - Operations Reference

**Version**: 0.1.0
**Date**: February 3, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Transaction Operations](#transaction-operations)
3. [Owner Management Operations](#owner-management-operations)
4. [Threshold Management](#threshold-management)
5. [Error Codes](#error-codes)
6. [GraphQL Queries](#graphql-queries)

---

## Overview

The Linera Multisig Application supports **8 core operations** divided into three categories:

| Category | Operations | Purpose |
|----------|------------|---------|
| **Transaction** | Submit, Confirm, Execute, Revoke | Manage transaction lifecycle |
| **Owner Management** | Add, Remove, Replace | Manage multisig participants |
| **Threshold** | Change | Modify confirmation requirements |

### Operation Flow Diagram

```

  Transaction Lifecycle                                          
                                                                 
  SubmitTransaction  ConfirmTransaction  ExecuteTransaction 
                                                               
                                                               
                                                               
   [nonce assigned]    [confirmations++]       [executed flag]   
   [auto-confirm]      [check threshold]       [actual transfer]
                                                                 
   RevokeConfirmation (can be called before execution)           



  Owner Management (Admin Operations)                            
                                                                 
  AddOwner  adds new participant                             
  RemoveOwner  removes participant (threshold safe)           
  ReplaceOwner  swaps one participant for another             



  Threshold Management                                           
                                                                 
  ChangeThreshold  modify M-of-N requirement                  

```

---

## Transaction Operations

### 1. SubmitTransaction

**Purpose**: Submit a new transaction for multisig approval

**Location**: `src/contract.rs:125-149`

**Operation Definition**:
```rust
pub enum MultisigOperation {
    SubmitTransaction {
        to: AccountOwner,      // Destination address
        value: u64,            // Amount to transfer
        data: Vec<u8>,         // Transaction data (calldata, etc.)
    },
    // ...
}
```

**Response**:
```rust
pub enum MultisigResponse {
    TransactionSubmitted {
        transaction_id: u64,   // Unique nonce assigned
    },
}
```

**Execution Flow**:
```
1. Verify caller is owner (ensure_is_owner)
2. Read current nonce
3. Increment nonce (nonce + 1)
4. Create Transaction struct:
   - to: destination address
   - value: amount
   - data: transaction data
   - nonce: current nonce (before increment)
   - confirmation_count: 0
   - executed: false
5. Store transaction in pending_transactions[nonce]
6. Auto-confirm from submitter (confirm_transaction_internal)
7. Return transaction_id (the nonce)
```

**State Changes**:
```rust
// Before
nonce: 0
pending_transactions: {}

// After
nonce: 1
pending_transactions: {
    0 → Transaction { to, value, data, nonce: 0, confirmations: 1, executed: false }
}
confirmations: {
    submitter → [0]
}
```

**Example Usage**:
```bash
# Via Linera CLI (when available)
linera operation \
  --application <multisig_app_id> \
  --operation SubmitTransaction \
  --arg-to User:destination_public_key \
  --arg-value 1000000 \
  --arg-data "0x"
```

**Key Features**:
-  Nonce-based uniqueness (no replay attacks)
-  Auto-confirmation from submitter (reduces friction)
-  Immediate persistence to state
-  Returns unique transaction ID

**Validation**:
- Caller must be an owner
- Nonce always increments (atomic)
- Transaction always stored (no pre-validation)

---

### 2. ConfirmTransaction

**Purpose**: Confirm a pending transaction

**Location**: `src/contract.rs:151-167`

**Operation Definition**:
```rust
pub enum MultisigOperation {
    ConfirmTransaction {
        transaction_id: u64,   // Transaction to confirm
    },
}
```

**Response**:
```rust
pub enum MultisigResponse {
    TransactionConfirmed {
        transaction_id: u64,
        confirmations: u64,    // Total confirmation count
    },
}
```

**Execution Flow**:
```
1. Verify caller is owner
2. Load transaction from pending_transactions[transaction_id]
3. Verify transaction exists
4. Verify transaction not executed
5. Check if caller already confirmed:
   - If yes: warn (idempotent), return current count
   - If no: continue
6. Add transaction_id to caller's confirmation list
7. Increment transaction.confirmation_count
8. Return new confirmation count
```

**State Changes**:
```rust
// Before
transaction.confirmation_count: 2
confirmations: {
    owner1 → [0]
    owner2 → [0]
}

// After (owner3 confirms)
transaction.confirmation_count: 3
confirmations: {
    owner1 → [0]
    owner2 → [0]
    owner3 → [0]  // Added
}
```

**Idempotency**:
```rust
// Can be called multiple times safely
if confirmed_txs.contains(&transaction_id) {
    warn!("Owner {:?} already confirmed transaction {}", caller, transaction_id);
    return transaction.confirmation_count;  // No-op
}
```

**Example Usage**:
```bash
linera operation \
  --application <multisig_app_id> \
  --operation ConfirmTransaction \
  --arg-transaction-id 0
```

**Key Features**:
-  Idempotent (safe to call multiple times)
-  Per-owner confirmation tracking
-  Returns current confirmation count
-  Prevents double-counting

---

### 3. ExecuteTransaction

**Purpose**: Execute a fully confirmed transaction

**Location**: `src/contract.rs:224-250`

**Operation Definition**:
```rust
pub enum MultisigOperation {
    ExecuteTransaction {
        transaction_id: u64,
    },
}
```

**Response**:
```rust
pub enum MultisigResponse {
    TransactionExecuted {
        transaction_id: u64,
    },
}
```

**Execution Flow**:
```
1. Verify caller is owner
2. Load transaction
3. Verify transaction exists
4. Verify transaction not executed (double-execution prevention)
5. CRITICAL: Verify confirmations >= threshold
   - If confirmations < threshold: panic (execution rejected)
   - If confirmations >= threshold: continue
6. Mark transaction.executed = true
7. TODO: Execute actual transfer (token integration)
8. Return success
```

**Threshold Enforcement**:
```rust
let threshold = *self.state.threshold.get();

if transaction.confirmation_count < threshold {
    panic!(
        "Insufficient confirmations: {} < {}",
        transaction.confirmation_count, threshold
    );
}
```

**State Changes**:
```rust
// Before
transaction: { confirmations: 3, executed: false }

// After
transaction: { confirmations: 3, executed: true }
```

**Example Usage**:
```bash
linera operation \
  --application <multisig_app_id> \
  --operation ExecuteTransaction \
  --arg-transaction-id 0
```

**Key Features**:
-  **CRITICAL**: Threshold enforcement
-  Double-execution prevention
-  Any owner can execute (not just submitter)
-  Actual token transfer is TODO

**Validation**:
- Caller must be an owner
- Transaction must exist
- Transaction must not be executed
- **confirmations >= threshold** (CRITICAL)

---

### 4. RevokeConfirmation

**Purpose**: Revoke a confirmation before execution

**Location**: `src/contract.rs:258-294`

**Operation Definition**:
```rust
pub enum MultisigOperation {
    RevokeConfirmation {
        transaction_id: u64,
    },
}
```

**Response**:
```rust
pub enum MultisigResponse {
    ConfirmationRevoked {
        transaction_id: u64,
    },
}
```

**Execution Flow**:
```
1. Verify caller is owner
2. Load transaction
3. CRITICAL: Verify transaction not executed
   - If executed: panic (cannot revoke after execution)
4. Load caller's confirmation list
5. Find transaction_id in list
6. Remove from list
7. Decrement confirmation_count (saturating_sub)
8. Return success
```

**Execution-Time Safety**:
```rust
if transaction.executed {
    panic!("Cannot revoke confirmation for executed transaction");
}
```

**State Changes**:
```rust
// Before
transaction.confirmation_count: 3
confirmations: {
    owner1 → [0, 1, 2]
}

// After (owner1 revokes tx 1)
transaction.confirmation_count: 2
confirmations: {
    owner1 → [0, 2]  // 1 removed
}
```

**Example Usage**:
```bash
linera operation \
  --application <multisig_app_id> \
  --operation RevokeConfirmation \
  --arg-transaction-id 0
```

**Key Features**:
-  Execution-time safety (cannot revoke executed txs)
-  Safe decrement (saturating_sub prevents underflow)
-  Per-owner revocation
-  Allows dynamic confirmation changes

**Use Cases**:
- Owner discovered transaction issue
- Changing transaction parameters (resubmit)
- Reducing confirmation count below threshold (pause execution)

---

## Owner Management Operations

### 5. AddOwner

**Purpose**: Add a new owner to the multisig

**Location**: `src/contract.rs:296-314`

**Operation Definition**:
```rust
pub enum MultisigOperation {
    AddOwner {
        owner: AccountOwner,   // New owner to add
    },
}
```

**Response**:
```rust
pub enum MultisigResponse {
    OwnerAdded {
        owner: AccountOwner,
    },
}
```

**Execution Flow**:
```
1. Verify caller is owner
2. Load current owners list
3. Check if new_owner already exists:
   - If yes: panic (duplicate prevention)
   - If no: continue
4. Append new_owner to owners list
5. Return success
```

**Duplicate Prevention**:
```rust
if owners.contains(&owner) {
    panic!("Owner already exists");
}
```

**State Changes**:
```rust
// Before
owners: [owner1, owner2, owner3]

// After
owners: [owner1, owner2, owner3, new_owner]
```

**Example Usage**:
```bash
linera operation \
  --application <multisig_app_id> \
  --operation AddOwner \
  --arg-owner User:new_public_key
```

**Key Features**:
-  Duplicate prevention
-  Immediate effect
-  Any owner can add (no governance)
-  Consider increasing threshold after adding

**Considerations**:
- New owner can participate immediately
- No automatic threshold adjustment
- May want to follow with ChangeThreshold

---

### 6. RemoveOwner

**Purpose**: Remove an owner from the multisig

**Location**: `src/contract.rs:316-341`

**Operation Definition**:
```rust
pub enum MultisigOperation {
    RemoveOwner {
        owner: AccountOwner,   // Owner to remove
    },
}
```

**Response**:
```rust
pub enum MultisigResponse {
    OwnerRemoved {
        owner: AccountOwner,
    },
}
```

**Execution Flow**:
```
1. Verify caller is owner
2. Load current owners list
3. Find owner in list:
   - If not found: panic (owner doesn't exist)
   - If found: continue
4. CRITICAL: Check new_count >= threshold
   - If new_count < threshold: panic (safety violation)
   - If new_count >= threshold: continue
5. Remove owner from list
6. Return success
```

**Threshold Safety**:
```rust
let threshold = *self.state.threshold.get();
if owners.len() < threshold as usize {
    panic!("Cannot remove owner: would go below threshold");
}
```

**State Changes**:
```rust
// Before
owners: [owner1, owner2, owner3, owner4, owner5]
threshold: 3

// After (remove owner5)
owners: [owner1, owner2, owner3, owner4]  // 4 >= 3 
threshold: 3  (still valid)
```

**Example Usage**:
```bash
linera operation \
  --application <multisig_app_id> \
  --operation RemoveOwner \
  --arg-owner User:owner_to_remove
```

**Key Features**:
-  **CRITICAL**: Threshold safety check
-  Owner existence validation
-  Prevents bricking the multisig
-  May want to decrease threshold first

**Safety Scenarios**:
```
Scenario 1 (SAFE):
  owners: 5, threshold: 3
  Remove owner → 4 owners, threshold still 3 

Scenario 2 (BLOCKED):
  owners: 3, threshold: 3
  Remove owner → 2 owners < threshold 3  (PANIC)
```

---

### 7. ReplaceOwner

**Purpose**: Replace an existing owner with a new one

**Location**: `src/contract.rs:366-397`

**Operation Definition**:
```rust
pub enum MultisigOperation {
    ReplaceOwner {
        old_owner: AccountOwner,   // Owner to replace
        new_owner: AccountOwner,   // Replacement owner
    },
}
```

**Response**:
```rust
pub enum MultisigResponse {
    OwnerReplaced {
        old_owner: AccountOwner,
        new_owner: AccountOwner,
    },
}
```

**Execution Flow**:
```
1. Verify caller is owner
2. Load current owners list
3. Find old_owner in list:
   - If not found: panic (old owner doesn't exist)
   - If found: continue
4. Check if new_owner already exists:
   - If yes: panic (duplicate)
   - If no: continue
5. In-place replacement (preserves order and count)
6. Return success
```

**Validation**:
```rust
if let Some(pos) = owners.iter().position(|o| o == &old_owner) {
    if owners.contains(&new_owner) {
        panic!("New owner already exists");
    }
    owners[pos] = new_owner.clone();
}
```

**State Changes**:
```rust
// Before
owners: [owner1, owner2, owner3, owner4]

// After (replace owner2 with new_owner)
owners: [owner1, new_owner, owner3, owner4]
// Count preserved: still 4 owners
// Threshold unaffected
```

**Example Usage**:
```bash
linera operation \
  --application <multisig_app_id> \
  --operation ReplaceOwner \
  --arg-old-owner User:old_key \
  --arg-new-owner User:new_key
```

**Key Features**:
-  Preserves owner count (threshold unaffected)
-  Duplicate prevention (new owner)
-  Existence validation (old owner)
-  In-place replacement (atomic)

**Use Cases**:
- Key rotation (security)
- Wallet migration
- Owner address change

---

## Threshold Management

### 8. ChangeThreshold

**Purpose**: Modify the number of confirmations required

**Location**: `src/contract.rs:343-364`

**Operation Definition**:
```rust
pub enum MultisigOperation {
    ChangeThreshold {
        threshold: u64,   // New threshold value
    },
}
```

**Response**:
```rust
pub enum MultisigResponse {
    ThresholdChanged {
        new_threshold: u64,
    },
}
```

**Execution Flow**:
```
1. Verify caller is owner
2. Load current owners list
3. Validate new threshold:
   - Cannot be 0: panic
   - Cannot exceed owner count: panic
4. Set new threshold
5. Return success
```

**Bounds Checking**:
```rust
if threshold == 0 {
    panic!("Threshold cannot be zero");
}

if threshold as usize > owners.len() {
    panic!("Threshold cannot exceed number of owners");
}
```

**State Changes**:
```rust
// Before
threshold: 3
owners: [owner1, owner2, owner3, owner4, owner5]

// After (change to 4)
threshold: 4
owners: [owner1, owner2, owner3, owner4, owner5]  // Unchanged
// Now requires 4 of 5 confirmations
```

**Example Usage**:
```bash
linera operation \
  --application <multisig_app_id> \
  --operation ChangeThreshold \
  --arg-threshold 4
```

**Key Features**:
-  Zero threshold prevention
-  Upper bound validation (<= owner count)
-  Immediate effect
-  Any owner can change (no governance)

**Scenarios**:
```
Increase Security:
  3 of 5 → 4 of 5 (more confirmations required)

Decrease Friction:
  4 of 5 → 3 of 5 (fewer confirmations required)

After Removing Owner:
  3 of 5 → 3 of 4 (maintain absolute number)

Before Adding Owner:
  3 of 4 → 4 of 5 (maintain ratio)
```

---

## Error Codes

### Panic Conditions

| Operation | Error | Cause |
|-----------|-------|-------|
| **All** | "Caller is not an owner" | Authorization failed |
| **Submit** | (none) | Always succeeds if authorized |
| **Confirm** | "Transaction not found" | Invalid transaction_id |
| **Confirm** | "Transaction already executed" | Too late to confirm |
| **Execute** | "Transaction not found" | Invalid transaction_id |
| **Execute** | "Transaction already executed" | Double-execution attempt |
| **Execute** | "Insufficient confirmations" | Threshold not met |
| **Revoke** | "Transaction not found" | Invalid transaction_id |
| **Revoke** | "Cannot revoke...executed" | Already executed |
| **AddOwner** | "Owner already exists" | Duplicate prevention |
| **RemoveOwner** | "Owner not found" | Invalid owner |
| **RemoveOwner** | "Cannot remove...below threshold" | Safety violation |
| **ReplaceOwner** | "Old owner not found" | Invalid old_owner |
| **ReplaceOwner** | "New owner already exists" | Duplicate |
| **ChangeThreshold** | "Threshold cannot be zero" | Invalid value |
| **ChangeThreshold** | "Threshold cannot exceed..." | Upper bound violation |

### Error Handling Pattern

```rust
// All operations follow this pattern:
async fn operation_handler(&mut self, ...) -> MultisigResponse {
    // 1. Authorization
    self.ensure_is_owner(&caller);

    // 2. Validation
    if invalid_condition {
        panic!("Descriptive error message");
    }

    // 3. State update
    // ...

    // 4. Return response
    MultisigResponse::OperationResult { ... }
}
```

---

## GraphQL Queries

### Query Interface

**Location**: `src/service.rs`

### Available Queries

#### 1. Get Owners

```graphql
query GetOwners {
  owners {
    # Returns: [AccountOwner]
  }
}
```

**Returns**: Array of current owner addresses

**Example**:
```json
{
  "data": {
    "owners": [
      "User:abc123...",
      "User:def456...",
      "User:ghi789..."
    ]
  }
}
```

---

#### 2. Get Threshold

```graphql
query GetThreshold {
  threshold
  # Returns: u64
}
```

**Returns**: Current confirmation threshold

**Example**:
```json
{
  "data": {
    "threshold": 3
  }
}
```

---

#### 3. Get Nonce

```graphql
query GetNonce {
  nonce
  # Returns: u64
}
```

**Returns**: Current transaction counter (next transaction ID)

**Example**:
```json
{
  "data": {
    "nonce": 42
  }
}
```

---

#### 4. Get Transaction

```graphql
query GetTransaction($id: UInt64!) {
  transaction(id: $id) {
    id
    to
    value
    data
    nonce
    confirmationCount
    executed
  }
}
```

**Returns**: Transaction details or null if not found

**Example**:
```json
{
  "data": {
    "transaction": {
      "id": 0,
      "to": "User:recipient...",
      "value": 1000000,
      "data": "0x",
      "nonce": 0,
      "confirmationCount": 3,
      "executed": false
    }
  }
}
```

---

#### 5. Check Confirmation Status

```graphql
query HasConfirmed($owner: AccountOwner!, $transactionId: UInt64!) {
  hasConfirmed(owner: $owner, transactionId: $transactionId)
  # Returns: Boolean
}
```

**Returns**: True if owner has confirmed this transaction

**Example**:
```json
{
  "data": {
    "hasConfirmed": true
  }
}
```

---

### Query Examples

#### Complete Transaction Status Check

```graphql
query TransactionStatus($txId: UInt64!) {
  transaction(id: $txId) {
    id
    confirmationCount
    executed
  }
  threshold
  owners
}
```

**Use Case**: Check if transaction is ready for execution

---

#### Owner Confirmation Status

```graphql
query OwnerConfirmations($txId: UInt64!, $owners: [AccountOwner!]!) {
  transaction(id: $txId) {
    confirmationCount
    executed
  }
  threshold
  confirmations: owners @_(include: $owners) {
    hasConfirmed(owner: $owner, transactionId: $txId)
  }
}
```

**Use Case**: Show which owners have confirmed

---

## Summary

### Operation Quick Reference

| Operation | Auth | State Change | Threshold Check |
|-----------|------|--------------|-----------------|
| SubmitTransaction |  Yes | nonce++, tx new | No |
| ConfirmTransaction |  Yes | confirmations++ | No |
| ExecuteTransaction |  Yes | executed=true | **Yes (CRITICAL)** |
| RevokeConfirmation |  Yes | confirmations-- | No |
| AddOwner |  Yes | owners++ | No |
| RemoveOwner |  Yes | owners-- | **Yes (safety)** |
| ReplaceOwner |  Yes | owners swap | No |
| ChangeThreshold |  Yes | threshold new | **Yes (bounds)** |

### Best Practices

1. **Always query before acting**:
   - Check `owners()` before owner management
   - Check `threshold()` before execution
   - Check `transaction(id)` before confirmation

2. **Handle idempotency**:
   - `ConfirmTransaction` is idempotent (safe to retry)
   - `SubmitTransaction` always increments nonce

3. **Mind the threshold**:
   - Cannot execute without sufficient confirmations
   - Cannot remove owners below threshold
   - Cannot set threshold to 0 or above owner count

4. **Use GraphQL queries**:
   - Efficient read-only access
   - Type-safe responses
   - No gas cost for queries

---

**Author**: PalmeraDAO
**License**: MIT
**Repository**: https://github.com/PalmeraDAO/linera.dev
