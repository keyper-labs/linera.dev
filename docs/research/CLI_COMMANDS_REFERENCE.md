# Linera CLI Commands Reference - Multi-Owner Chain Testing

**Validated on**: Conway Testnet (v0.15.8)
**Last Updated**: February 3, 2026

---

## Table of Contents

1. [Environment Setup](#environment-setup)
2. [Wallet Commands](#wallet-commands)
3. [Multi-Owner Chain Commands](#multi-owner-chain-commands)
4. [Query Commands](#query-commands)
5. [Validation Commands](#validation-commands)
6. [gRPC Direct Commands](#grpc-direct-commands)

---

## Environment Setup

### Required Environment Variables

```bash
# Set Linera client environment
export LINERA_WALLET="/path/to/wallet.json"
export LINERA_KEYSTORE="/path/to/keystore.json"
export LINERA_STORAGE="/path/to/client.db"  # RocksDB storage
```

### Working Directory Structure

```
/tmp/linera-conway-<timestamp>/
 wallet.json          # Wallet with chain IDs and keys
 keystore.json        # Encrypted key storage
 client.db/           # RocksDB local storage
```

---

## Wallet Commands

### Initialize Wallet from Faucet

```bash
# Creates wallet with 2 chains, each funded from faucet
linera wallet-init \
  --from-faucet https://faucet.testnet-conway.linera.net \
  --with-weak-keys
```

**Output**: Creates `wallet.json` with 2 owner chains

### View Wallet Contents

```bash
# View wallet JSON structure
cat "$LINERA_WALLET" | jq '.'

# List all chain IDs in wallet
cat "$LINERA_WALLET" | jq -r '.chains[].chain_id'

# Get owner public keys
cat "$LINERA_WALLET" | jq -r '.chains[].key_pair[0].public_key'
```

---

## Multi-Owner Chain Commands

### Create Multi-Owner Chain

```bash
# Extract chain IDs and owners from wallet
CHAIN1=$(cat "$LINERA_WALLET" | jq -r '.chains[0].chain_id')
CHAIN2=$(cat "$LINERA_WALLET" | jq -r '.chains[1].chain_id')
OWNER1=$(cat "$LINERA_WALLET" | jq -r '.chains[0].key_pair[0].public_key')
OWNER2=$(cat "$LINERA_WALLET" | jq -r '.chains[1].key_pair[0].public_key')

# Create multi-owner chain with both owners
linera open-multi-owner-chain \
  --from "$CHAIN1" \
  --owners "$OWNER1" "$OWNER2" \
  --with-initial-balances "$CHAIN2:10"
```

**Parameters**:
- `--from`: Source chain ID (must have sufficient balance)
- `--owners`: Space-separated list of owner public keys
- `--with-initial-balances`: `CHAIN_ID:AMOUNT` format

**Result**: New chain added to wallet with multi-owner configuration

---

## Query Commands

### Query Chain Balance

```bash
# Query specific chain balance
linera query-balance <CHAIN_ID>

# Example:
linera query-balance 4888610445c3f2e65fd23f0deceaecff469c9c9149fa6453545a3ca167bde4c7
# Output: 10
```

### Query All Balances in Wallet

```bash
# Get all chain IDs
CHAIN_COUNT=$(cat "$LINERA_WALLET" | jq '.chains | length')

# Query balance for each chain
for i in $(seq 0 $((CHAIN_COUNT - 1))); do
    CHAIN_ID=$(cat "$LINERA_WALLET" | jq -r ".chains[$i].chain_id")
    echo "Chain $i: $CHAIN_ID"
    linera query-balance "$CHAIN_ID"
done
```

---

## Validation Commands

### Sync with Validators

```bash
# Sync local state with Conway validators
linera sync

# Measure sync time
START=$(date +%s%3N)
linera sync
END=$(date +%s%3N)
echo "Sync time: $((END - START))ms"
```

**Expected sync time on Conway**: ~500ms

### Validate Chain Creation

```bash
# 1. Check wallet has new chain
CHAIN_COUNT_BEFORE=$(cat "$LINERA_WALLET" | jq '.chains | length')
# ... create multi-owner chain ...
CHAIN_COUNT_AFTER=$(cat "$LINERA_WALLET" | jq '.chains | length')
# Should increase by 1

# 2. Verify multi-owner chain balance
MULTISIG_CHAIN=$(cat "$LINERA_WALLET" | jq -r '.chains[-1].chain_id')
linera query-balance "$MULTISIG_CHAIN"
# Should equal initial balance

# 3. Verify source chain decreased
SOURCE_CHAIN=$(cat "$LINERA_WALLET" | jq -r '.chains[0].chain_id')
linera query-balance "$SOURCE_CHAIN"
# Should equal (100 - initial_balance - fees)
```

---

## gRPC Direct Commands

### Chain State Query

```bash
# Query chain state via gRPC
grpcurl -plaintext \
  validator-1.testnet-conway.linera.net:443 \
  linera.storage.StorageService/GetChainState \
  -d '{
    "chain_id": "4888610445c3f2e65fd23f0deceaecff469c9c9149fa6453545a3ca167bde4c7"
  }'
```

### List All Validators

```bash
# Conway testnet validators
for i in 1 2 3 4; do
    echo "validator-$i.testnet-conway.linera.net:443"
done
```

### Query Specific Validator

```bash
# Query chain from specific validator
grpcurl -plaintext \
  validator-2.testnet-conway.linera.net:443 \
  linera.storage.StorageService/GetChainState \
  -d '{"chain_id": "<CHAIN_ID>"}'
```

---

## Complete Workflow Example

```bash
#!/bin/bash
# Complete multi-owner chain creation workflow

# 1. Setup environment
WORK_DIR="$(mktemp -d -t linera-conway-XXXXXX)"
export LINERA_WALLET="$WORK_DIR/wallet.json"
export LINERA_KEYSTORE="$WORK_DIR/keystore.json"
export LINERA_STORAGE="$WORK_DIR/client.db"

echo "Working directory: $WORK_DIR"

# 2. Initialize wallet
linera wallet-init \
  --from-faucet https://faucet.testnet-conway.linera.net \
  --with-weak-keys

# 3. Query initial state
CHAIN1=$(cat "$LINERA_WALLET" | jq -r '.chains[0].chain_id')
echo "Source chain: $CHAIN1"
linera query-balance "$CHAIN1"

# 4. Create multi-owner chain
CHAIN2=$(cat "$LINERA_WALLET" | jq -r '.chains[1].chain_id')
OWNER1=$(cat "$LINERA_WALLET" | jq -r '.chains[0].key_pair[0].public_key')
OWNER2=$(cat "$LINERA_WALLET" | jq -r '.chains[1].key_pair[0].public_key')

linera open-multi-owner-chain \
  --from "$CHAIN1" \
  --owners "$OWNER1" "$OWNER2" \
  --with-initial-balances "$CHAIN2:10"

# 5. Sync
linera sync

# 6. Validate
MULTISIG_CHAIN=$(cat "$LINERA_WALLET" | jq -r '.chains[-1].chain_id')
echo "Multi-owner chain: $MULTISIG_CHAIN"
linera query-balance "$MULTISIG_CHAIN"
linera query-balance "$CHAIN1"

echo "Validation complete!"
```

---

## Troubleshooting

### Error: "odd number of digits"

**Cause**: Chain ID hex string has odd length

**Solution**: Ensure chain IDs are extracted from `wallet.json` using `jq`

```bash
# Correct
CHAIN_ID=$(cat "$LINERA_WALLET" | jq -r '.chains[0].chain_id')

# Incorrect (manual typo prone)
CHAIN_ID="3c357e77e0be145519909833fa384724e5750a443aa29500d9dd226a41eb3dc"  # May have formatting issues
```

### Error: "insufficient balance"

**Cause**: Source chain doesn't have enough tokens

**Solution**: Query balance before creating multi-owner chain

```bash
linera query-balance "$SOURCE_CHAIN"
# Ensure >= 10 tokens for transfer
```

### Error: "wallet not found"

**Cause**: `LINERA_WALLET` environment variable not set

**Solution**: Set environment variables before running commands

```bash
export LINERA_WALLET="/path/to/wallet.json"
export LINERA_KEYSTORE="/path/to/keystore.json"
export LINERA_STORAGE="/path/to/client.db"
```

---

## Conway Testnet Endpoints

| Service | Endpoint |
|---------|----------|
| **Faucet** | `https://faucet.testnet-conway.linera.net` |
| **Validator 1** | `validator-1.testnet-conway.linera.net:443` |
| **Validator 2** | `validator-2.testnet-conway.linera.net:443` |
| **Validator 3** | `validator-3.testnet-conway.linera.net:443` |
| **Validator 4** | `validator-4.testnet-conway.linera.net:443` |
| **Portal** | `https://linera.dev/public/devnet-1/explorer` |

---

## Quick Reference Card

```bash
# Wallet init
linera wallet-init --from-faucet https://faucet.testnet-conway.linera.net --with-weak-keys

# Create multi-owner
CHAIN1=$(jq -r '.chains[0].chain_id' "$LINERA_WALLET")
CHAIN2=$(jq -r '.chains[1].chain_id' "$LINERA_WALLET")
OWNER1=$(jq -r '.chains[0].key_pair[0].public_key' "$LINERA_WALLET")
OWNER2=$(jq -r '.chains[1].key_pair[0].public_key' "$LINERA_WALLET")
linera open-multi-owner-chain --from "$CHAIN1" --owners "$OWNER1" "$OWNER2" --with-initial-balances "$CHAIN2:10"

# Sync
linera sync

# Query balance
linera query-balance <CHAIN_ID>
```

---

**See Also**:
- [`CONWAY_TESTNET_VALIDATION.md`](./CONWAY_TESTNET_VALIDATION.md) - Test results
- [`../../scripts/multisig/create_multisig.sh`](../../scripts/multisig/create_multisig.sh) - Automated script
