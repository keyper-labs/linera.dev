# Detailed Architecture: Threshold Signatures Multisig

This document explains the technical architecture of the threshold signatures system for Linera multisig.

---

## Table of Contents

1. [Fundamental Concepts](#fundamental-concepts)
2. [System Architecture](#system-architecture)
3. [Complete Flow](#complete-flow)
4. [Technical Specifications](#technical-specifications)
5. [FROST Implementation](#frost-implementation)
6. [Security and Validation](#security-and-validation)

---

## Fundamental Concepts

### What is a Threshold Signature?

A **threshold signature** is a cryptographic signature that requires **m** of **n** participants to collaborate to produce a valid signature, but which **verifies as a single signature**.

```
Traditional Signature (Bitcoin Multisig):
- Each owner signs individually: σ₁, σ₂, σ₃
- ALL signatures are verified on-chain
- Gas cost: Grows with number of signatures

Threshold Signature (FROST):
- Owners collaborate offline: σ₁, σ₂, σ₃ → σ_threshold
- ONE signature is verified on-chain
- Gas cost: Constant (like a single signature)
```

### Key Advantages

| Aspect | Traditional Multisig | Threshold Signatures |
|---------|---------------------|---------------------|
| **Signature size** | O(m) individual signatures | O(1) aggregated signature |
| **Verification cost** | O(m) verifications | O(1) verification |
| **Privacy** | Reveals who signed | Does not reveal signers |
| **Scalability** | Worsens with more owners | Constant |

---

## System Architecture

### Components

```

                      Frontend Layer                             
         
    Owner 1 App       Owner 2 App       Owner 3 App      
                                                         
    Private Key 1     Private Key 2     Private Key 3    
    Key Share 1       Key Share 2       Key Share 3      
         

                              ↓
                    [Coordination Protocol]
                              ↓

                      Backend Layer                              
     
    REST API + WebSocket                                      
    - Transaction proposals                                  
    - Signature coordination                                 
    - Signature aggregation (threshold)                      
    - Transmission to Linera                                 
     
                     ↓ NO private keys                          
     
    PostgreSQL + Redis                                        
    - Pending proposals                                      
    - Signature state                                        
    - Nonces                                                 
     

                              ↓

                    Linera Network                               
     
    ThresholdMultisigContract (Wasm)                          
    - Verifies threshold signature                           
    - Executes transfer                                      
    - Maintains nonce                                        
     

```

### Explicit Self-Custody

```typescript
// WHAT THE BACKEND DOES NOT HAVE:
interface BackendState {
  // NO private keys
  privateKeys: Map<UserId, Uint8Array>; // NEVER

  // NO FROST key shares
  keyShares: Map<UserId, FrostShare>; // NEVER

  // NO ability to sign for users
  signingService: ThresholdSigning; // NEVER
}

// WHAT THE BACKEND DOES HAVE:
interface BackendState {
  // Proposal metadata only
  proposals: Map<ProposalId, {
    id: string;
    creator: string; // Public address only
    created_at: Date;
    threshold_signatures: SignatureShare[]; // Public shares only
    is_complete: boolean;
  }>;

  // Coordination, not custody
  websocket: WebSocket; // To coordinate signers
}
```

---

## Complete Flow

### Phase 1: Setup (DKG - Distributed Key Generation)

Before creating the multisig, owners execute a cooperative setup phase:

```typescript
// Step 1: Each owner generates their key share
// Owner 1:
const share1 = Frost.generateKeyShare();
// -> { secret_share: s1, public_share: P1 }

// Owner 2:
const share2 = Frost.generateKeyShare();
// -> { secret_share: s2, public_share: P2 }

// Owner 3:
const share3 = Frost.generateKeyShare();
// -> { secret_share: s3, public_share: P3 }

// Step 2: Each owner shares their public_share with others
// This can be done off-band (email, messaging, etc.)

// Step 3: Each owner calculates the aggregate public key
const aggregatePublicKey = share1.public_share
  .add(share2.public_share)
  .add(share3.public_share);

// NOTE: The aggregate public key is the same for all owners
// This is the key that will be used in the Wasm contract
```

### Phase 2: Create Multisig

```typescript
// Any owner (or all coordinated) creates the contract
const params = {
  owners: [address1, address2, address3],
  threshold: 2, // 2-of-3
  aggregate_public_key: aggregatePublicKey.toBytes(),
};

await linera.publish("./contract", params);
```

### Phase 3: Create Proposal

```typescript
// Owner 1 creates transfer proposal
const proposal = {
  to: "recipient_address",
  amount: 1000000,
  nonce: await contract.getNonce(),
  message: createMessage({
    nonce: 0,
    operation: "transfer",
    to: "recipient_address",
    amount: 1000000,
  }),
};

// Proposal is saved in backend (off-chain)
await backend.createProposal(proposal);
```

### Phase 4: Collect Signatures

```typescript
// Owner 1 signs with their key share
const signature1 = Frost.sign(share1.secret_share, proposal.message);

// Send signature to backend
await backend.addSignature(proposalId, signature1);

// Owner 2 signs
const signature2 = Frost.sign(share2.secret_share, proposal.message);

await backend.addSignature(proposalId, signature2);

// Backend detects that threshold was reached
if (signatures.length >= threshold) {
  // Aggregate signatures into a single threshold signature
  const thresholdSignature = Frost.aggregate([
    signature1,
    signature2,
  ]);

  // Execute on-chain
  await executeOnChain(proposal, thresholdSignature);
}
```

### Phase 5: Execute On-Chain

```typescript
// Backend transmits the operation with threshold signature
const operation = {
  ExecuteWithThresholdSignature: {
    to: proposal.to,
    amount: proposal.amount,
    nonce: proposal.nonce,
    threshold_signature: thresholdSignature.toBytes(),
    message: proposal.message,
  },
};

await linera.executeOperation(contractAddress, operation);
```

### Phase 6: On-Chain Verification

```rust
// In the Wasm contract
fn execute_operation(op: MultisigOperation) {
    // 1. Verify nonce
    assert!(op.nonce == state.nonce(), "Invalid nonce");

    // 2. Verify threshold signature
    // The aggregate public key is in the contract state
    let is_valid = ed25519::verify(
        &state.aggregate_public_key,
        &op.message,
        &op.threshold_signature,
    );
    assert!(is_valid, "Invalid threshold signature");

    // 3. Execute transfer
    runtime.transfer(from, op.to, op.amount);

    // 4. Increment nonce
    state.increment_nonce();
}
```

---

## Technical Specifications

### Message to Sign

```rust
pub struct ThresholdMessage {
    pub nonce: u64,
    pub operation_type: String,
    pub operation_data: Vec<u8>,
}

impl ThresholdMessage {
    pub fn to_bytes(&self) -> Vec<u8> {
        // Simple encoding to avoid complexity
        let mut bytes = Vec::new();
        bytes.extend_from_slice(&self.nonce.to_be_bytes());
        bytes.extend_from_slice(self.operation_type.as_bytes());
        bytes.extend_from_slice(&(self.operation_data.len() as u64).to_be_bytes());
        bytes.extend_from_slice(&self.operation_data);
        bytes
    }
}
```

### On-Chain Operation

```rust
pub enum MultisigOperation {
    ExecuteWithThresholdSignature {
        to: Owner,
        amount: u64,
        nonce: u64,
        threshold_signature: Vec<u8>, // 64 bytes for Ed25519
        message: Vec<u8>,
    },
}
```

### Contract State

```rust
pub struct MultisigState {
    pub owners: Vec<Owner>,           // List of owners (for info)
    pub threshold: u64,                // m-of-n
    pub aggregate_public_key: Vec<u8>, // 32 bytes for Ed25519
    pub nonce: u64,                    // Replay protection
}
```

---

## FROST Implementation

### Available Rust Libraries

```toml
[dependencies]
# Option 1: frost-ed25519 (experimental)
frost-ed25519 = "0.1"

# Option 2: Implement from scratch following RFC
# See: https://datatracker.ietf.org/doc/html/rfc9591

# Option 3: Use libsodium bindings
libsodium-sys = "0.2"
```

### Basic FROST Structure

```rust
use frost_ed25519::{
    Participant, Identifier,
    keys::{KeyPackage, SecretShare, PublicKeyPackage},
    round1::{SigningCommitments, SigningNonces},
    round2::{SignatureShare, AggregateSignature},
};

/// DKG Phase (Distributed Key Generation)
async fn dkg_phase(
    participants: Vec<Participant>,
) -> (Vec<SecretShare>, PublicKeyPackage) {
    // Each participant generates their share
    let secret_shares: Vec<SecretShare> = participants
        .iter()
        .map(|p| KeyPackage::generate_participant_share(p.identifier))
        .collect();

    // Share public shares
    let public_package = PublicKeyPackage::aggregate_all(
        secret_shares.iter().map(|s| s.public_share()),
    );

    (secret_shares, public_package)
}

/// Sign with threshold scheme
fn threshold_sign(
    secret_share: &SecretShare,
    message: &[u8],
    signer_identifier: Identifier,
) -> SignatureShare {
    // Round 1: Generate commitment
    let nonces = SigningNonces::generate(signer_identifier);

    // Round 1: Share commitment
    let commitments = SigningCommitments::new(nonces.clone());

    // Round 2: Receive commitments from other signers
    // ...

    // Round 2: Generate signature share
    let signature_share = secret_share.sign(
        message,
        nonces,
        commitments,
        // ... commitments from other signers
    );

    signature_share
}

/// Aggregate signatures into threshold signature
fn aggregate_signatures(
    signature_shares: Vec<SignatureShare>,
) -> AggregateSignature {
    AggregateSignature::aggregate(signature_shares)
}

/// Verify threshold signature
fn verify_threshold(
    public_key: &PublicKey,
    message: &[u8],
    signature: &AggregateSignature,
) -> bool {
    public_key.verify(message, signature).is_ok()
}
```

---

## Security and Validation

### Security Properties

**Self-Custodial**:
- Private keys never leave the frontend
- Backend only coordinates, never signs
- Funds controlled by Wasm contract

**Threshold Enforcement**:
- Cryptographically impossible to sign without m participants
- No backdoor or bypass possible

**Replay Protection**:
- Nonce increments with each operation
- Each signature can only be used once

**On-Chain Verification**:
- Anyone can verify on blockchain
- No trust in server for validation

### On-Chain Validations

```rust
fn validate_operation(op: &MultisigOperation, state: &MultisigState) -> Result<(), Error> {
    // 1. Validate nonce
    if op.nonce != state.nonce {
        return Err(Error::InvalidNonce);
    }

    // 2. Validate signature format
    if op.threshold_signature.len() != 64 {
        return Err(Error::InvalidSignatureFormat);
    }

    // 3. Validate threshold signature
    let public_key = PublicKey::from_bytes(&state.aggregate_public_key)?;
    let signature = Signature::from_bytes(&op.threshold_signature)?;

    if !public_key.verify(&op.message, &signature) {
        return Err(Error::InvalidSignature);
    }

    // 4. Validate amount (optional: limits)
    if op.amount > MAX_AMOUNT {
        return Err(Error::AmountTooHigh);
    }

    Ok(())
}
```

### Error Handling

```rust
pub enum MultisigError {
    InvalidNonce,
    InvalidSignature,
    InvalidSignatureFormat,
    AmountTooHigh,
    InvalidRecipient,
    ContractPaused,
}

impl MultisigError {
    pub fn log_message(&self) -> &str {
        match self {
            Self::InvalidNonce => "Invalid nonce: possible replay attack",
            Self::InvalidSignature => "Invalid threshold signature",
            Self::InvalidSignatureFormat => "Incorrect signature format",
            Self::AmountTooHigh => "Amount exceeds maximum allowed",
            Self::InvalidRecipient => "Invalid recipient",
            Self::ContractPaused => "Contract in emergency pause",
        }
    }
}
```

---

## Comparison with Other Systems

### vs Safe (Ethereum)

| Aspect | Safe (Ethereum) | Threshold (Linera) |
|---------|----------------|-------------------|
| **Model** | m-of-n confirmations on-chain | m-of-n threshold signature off-chain |
| **Proposals** | On-chain | Off-chain (backend DB) |
| **Gas Cost** | Grows with confirmations | Constant |
| **Privacy** | Public (who confirmed) | Private (does not reveal signers) |

### vs Gnosis Safe

| Aspect | Gnosis Safe | Threshold (Linera) |
|---------|-------------|-------------------|
| **UX** | Very similar | Different (fewer on-chain transactions) |
| **Flexibility** | High (modular) | Medium (fixed in Wasm) |
| **Security** | Audited | To be audited |

---

## Implementation Roadmap

### Phase 1: Proof of Concept
- [x] Architecture design
- [x] Simplified Wasm contract
- [x] Documentation

### Phase 2: Basic Implementation ⏳
- [ ] Compile Wasm contract
- [ ] Verify absence of opcode 252
- [ ] Deploy to testnet
- [ ] Basic transfer test

### Phase 3: FROST Implementation ⏳
- [ ] Integrate FROST library
- [ ] Implement DKG phase
- [ ] Implement signing phase
- [ ] Test threshold signatures

### Phase 4: Frontend Integration ⏳
- [ ] Wallet with key shares
- [ ] UI for proposals
- [ ] UI for signatures
- [ ] Real-time coordination

### Phase 5: Backend Integration ⏳
- [ ] REST API
- [ ] WebSocket for coordination
- [ ] PostgreSQL for proposals
- [ ] Integration with @linera/client

---

## Conclusion

The threshold signatures architecture offers a viable path to implement self-custodial multisig on Linera while the opcode 252 problem is resolved.

**Next steps**:
1. Compile and verify opcode 252 is absent
2. Deploy to testnet
3. Test basic functionality
4. Evaluate if FROST is required or placeholder is sufficient

---

**Last updated**: 2026-02-04
**Author**: Alternative experiment for linera.dev
