# Linera Infrastructure Analysis

> **Analysis Date**: February 2, 2026
> **Purpose**: Comprehensive analysis of SDK, API, and Wallet capabilities for multisig platform development

---

## Executive Summary

This document consolidates infrastructure analysis from multiple research sources to provide a complete picture of Linera's development ecosystem. Key findings indicate that Linera has a **maturing Rust SDK** with **limited wallet options** and **emerging API documentation**.

---

## 1. SDK Analysis

### 1.1 Rust SDK (Primary)

**Status**: PRODUCTION-READY

**Capabilities**:
- Chain creation (single-owner, multi-owner)
- Block proposal and signing
- Cross-chain messaging
- Application deployment (Wasm bytecode)
- State queries and operations
- Ed25519 signature handling

**Key Components**:
- `linera-sdk` - Core SDK for application development
- `linera-storage` - Persistent storage layer
- `linera-service` - GraphQL endpoint interface
- `linera-views` - Data views for cross-chain queries

**Multisig-Relevant APIs**:
```rust
// Chain creation with multiple owners
ChainId::create(owners: Vec<Owner>, config: ChainConfig)

// Multi-owner block proposal
Block::propose_with_owner(owner: Owner, operations: Vec<Operation>)

// Cross-chain messaging
Messenger::send_message(recipient: ChainId, message: Message)
```

**Maturity Assessment**: HIGH
- Well-documented core concepts
- Active GitHub repository
- Example applications provided
- Community support available

---

### 1.2 TypeScript SDK (Frontend)

**Status**: BETA/EMERGING

**Capabilities**:
- Wallet connection (if wallet exists)
- Transaction signing
- State queries via GraphQL
- Cross-chain message handling

**Limitations**:
- Documentation scattered
- Not feature-complete with Rust SDK
- Limited multisig examples

**Recommendation**: Use for frontend-only operations. Backend should use Rust SDK or Python bindings.

---

### 1.3 Python SDK

**Status**: UNKNOWN/UNDOCUMENTED

**Finding**: No official Python SDK found in scraped documentation or GitHub repository.

**Workaround Options**:
1. Use Python subprocess to call Rust CLI tools
2. Create Python bindings via PyO3
3. Use REST API wrapper around Linera service

**Recommendation**: Budget for additional development if Python backend is required.

---

## 2. API Capabilities

### 2.1 GraphQL API

**Endpoint**: `/graphql` (per-chain GraphQL endpoint)

**Capabilities**:
- Chain state queries
- Application state queries
- Cross-chain message queries
- Transaction history

**Example Queries**:
```graphql
query GetChainState($chainId: ID!) {
    chain(id: $chainId) {
        state
        applications {
            id
            state
        }
        pendingMessages {
            id
            sender
            payload
        }
    }
}
```

**Limitations**:
- Read-only (no mutations via GraphQL)
- Per-chain endpoints (not unified)
- Documentation incomplete

---

### 2.2 REST API (Proposed for Multisig Platform)

**Not Native**: Linera does not provide a REST API. Our platform must implement one.

**Recommended Endpoints**:

```http
# Chain Management
POST   /api/v1/chains                    # Create multi-owner chain
GET    /api/v1/chains/:id                 # Get chain details
PUT    /api/v1/chains/:id/owners          # Add/remove owners

# Application Management
POST   /api/v1/applications               # Deploy multisig application
GET    /api/v1/applications/:id           # Get application state
POST   /api/v1/applications/:id/execute   # Execute operation

# Multisig Operations
POST   /api/v1/wallets                    # Create multisig wallet
POST   /api/v1/proposals                  # Create proposal
POST   /api/v1/proposals/:id/approve      # Approve proposal
POST   /api/v1/proposals/:id/execute      # Execute proposal

# WebSocket
WS     /api/v1/ws                         # Real-time updates
```

---

### 2.3 Cross-Chain Messaging API

**Mechanism**: Asynchronous message passing between chains

**Key Operations**:
```rust
// Send message to another chain
messenger.send_message(recipient_chain, message);

// Query inbox for incoming messages
let messages = inbox.query_messages();

// Process messages (in receiver chain)
for message in messages {
    application.handle_message(message);
}
```

**Use Cases for Multisig**:
- Notify owners of pending proposals
- Collect approvals from multiple chains
- Broadcast execution confirmation

---

## 3. Wallet Analysis

### 3.1 Official Linera Wallet

**Status**: UNCERTAIN/LIMITED DOCUMENTATION

**Finding**: scraped documentation does not clearly describe a production-ready web wallet.

**Evidence**:
- Wallet mentioned in design patterns
- Manual key entry discussed as fallback
- No wallet connector documentation found

**Uncertainties**:
- Does a browser extension exist?
- Is there a mobile wallet?
- What wallet standards are supported (EIP-1193, WCIP-style)?

---

### 3.2 Wallet Integration Options

#### Option A: Wallet Connector (If Available)

**Assumptions**:
- Linera has or will have a wallet connector
- Similar to MetaMask or StarKey (Supra)

**Implementation**:
```typescript
import { LineraWallet } from '@linera/wallet-sdk';

const connector = new LineraWallet();
await connector.connect();
const account = await connector.getAccount();
const signature = await connector.signTransaction(transaction);
```

**Risk**: HIGH - connector may not exist or be immature

---

#### Option B: Manual Key Entry (Fallback)

**Approach**:
- User manually enters private key or mnemonic
- Keys held in browser memory only
- Signature performed in browser via SDK

**Security Concerns**:
- Private key exposure risk
- No hardware wallet support
- User error potential

**UX Concerns**:
- Not user-friendly for non-technical users
- Educational burden on security
- Friction in onboarding

---

#### Option C: QR Code Signing (Proposed)

**Approach**:
1. Frontend generates unsigned transaction QR code
2. User scans with mobile wallet (if exists)
3. Mobile wallet signs and returns signed QR
4. Frontend submits signed transaction

**Requirements**:
- Mobile wallet with QR support
- Or offline signing tool

**Status**: RESEARCH NEEDED - confirm if supported

---

### 3.3 Key Management Architecture

**Recommended Approach**:

```
┌─────────────────────────────────────────────────────────────┐
│                    Key Management Flow                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. User generates Ed25519 key pair                         │
│     ├─ Option A: Manual entry (private key to browser)      │
│     ├─ Option B: Wallet connector (if available)            │
│     └─ Option C: QR code signing (mobile wallet)            │
│                                                              │
│  2. Keys stored ONLY in browser memory (session)            │
│     ├─ Never persisted to server                            │
│     ├─ Cleared on page refresh                              │
│     └─ User must re-enter on each session                   │
│                                                              │
│  3. Signing operations                                      │
│     ├─ Browser SDK signs operations                         │
│     ├─ Signature sent to backend                             │
│     └─ Backend verifies Ed25519 signature                   │
│                                                              │
│  4. Multi-owner coordination                                │
│     ├─ Each owner has independent key pair                  │
│     ├─ Approvals collected via cross-chain messages         │
│     └─ Threshold verification in smart contract              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Cryptographic Primitives

### 4.1 Signature Scheme

**Algorithm**: Ed25519

**Characteristics**:
- 256-bit security level
- Fast signing and verification
- Deterministic signatures
- No RFC 6979 randomness required

**Usage in Linera**:
- Block authentication
- Operation authentication
- Cross-chain message authentication
- Chain ownership verification

---

### 4.2 Multi-Owner Authentication

**Mechanism**: Application-Level

**How It Works**:
1. Each owner has Ed25519 key pair
2. Owners propose blocks with their signature
3. Application tracks approvals in state
4. Threshold logic implemented in contract
5. No native threshold scheme at protocol level

**Example**:
```rust
// Check if approval is valid
if let Some(proposal) = state.pending_transactions.get(tx_id) {
    if proposal.approvals.contains(&owner) {
        return Err("Already approved");
    }
    // Verify signature
    let signature = verify_ed25519(signature, message, owner.public_key)?;
    // Add approval
    proposal.approvals.insert(owner);
}
```

---

## 5. Development Environment

### 5.1 Local Development

**Tools Required**:
- Linera CLI (`linera` command)
- Local validator (for testing)
- Rust toolchain (for smart contract development)
- Node.js (for frontend)

**Setup**:
```bash
# Install Linera CLI
cargo install linera-sdk

# Start local validator
linera-net start

# Create test chain
linera create-chain --owners owner1,owner2,owner3
```

---

### 5.2 Testnet Access

**Status**: NEEDS VERIFICATION

**Action Required**:
- Confirm testnet endpoint availability
- Testnet faucet for test tokens
- Testnet explorer for transaction verification
- Testnet stability for development

---

## 6. Gaps and Unknowns

### 6.1 Critical Gaps

| Area | Gap | Impact | Priority |
|------|-----|--------|----------|
| **Wallet Integration** | No clear wallet connector documentation | HIGH | Must resolve in Week 1 |
| **Python SDK** | No official Python SDK | MEDIUM | Budget for bindings or Rust wrapper |
| **Fee Model** | Transaction costs not documented | MEDIUM | Research during PoC |
| **Testnet Access** | Uncertain if testnet is stable | HIGH | Verify before committing |

### 6.2 Research Needed

1. **Wallet Ecosystem**: GitHub search for Linera wallet implementations
2. **Fee Structure**: Research transaction costs and gas model
3. **EVM Timeline**: Confirm Solidity support timeline (Q2'25?)
4. **Testnet Stability**: Benchmark testnet uptime and latency

---

## 7. Recommendations

### 7.1 Immediate Actions (Week 1)

1. **Verify Testnet Access**
   - Confirm testnet endpoint is operational
   - Test faucet for token distribution
   - Validate transaction submission

2. **Research Wallet Options**
   - Search GitHub for Linera wallet projects
   - Contact Linera team for wallet guidance
   - Evaluate manual key entry UX requirements

3. **Proof of Concept**
   - Build minimal multisig contract
   - Test multi-owner chain creation
   - Validate cross-chain messaging

### 7.2 Architecture Decisions

**SDK Choice**: Use Rust SDK for backend, TypeScript SDK for frontend

**Wallet Strategy**: Plan for manual key entry with QR code signing future

**API Approach**: Build custom REST API wrapping Linera SDK operations

**Smart Contract**: Implement m-of-n threshold logic in Wasm application

---

## 8. Comparison with Reference Projects

| Infrastructure Aspect | Hathor | Supra | Linera |
|-----------------------|--------|-------|--------|
| **Primary SDK** | Python, TS | TypeScript, Python | Rust |
| **Wallet** | Headless Wallet | StarKey (official) | UNCERTAIN |
| **Multisig** | P2SH (native) | Native module | Application-level |
| **API** | REST (Headless) | REST (RPC) | GraphQL (query only) |
| **Testnet** | Stable | Stable | UNCERTAIN |
| **Documentation** | Good | Excellent | Limited |

---

## 9. Risk Assessment

### High Risk Items

1. **Wallet Integration Uncertainty**
   - Risk: May need to build custom wallet integration
   - Mitigation: Plan for manual key entry, research GitHub

2. **SDK Imaturity**
   - Risk: Limited documentation, potential bugs
   - Mitigation: Budget for research, Linera community support

3. **Testnet Stability**
   - Risk: Testnet may be unstable for development
   - Mitigation: Contingency time in schedule, local validator fallback

### Medium Risk Items

1. **Python SDK Absence**
   - Risk: Backend may need Rust instead of Python
   - Mitigation: Python bindings via PyO3, or Rust backend

2. **Fee Model Unknown**
   - Risk: Transaction costs may be high
   - Mitigation: Research during PoC, optimize operations

---

## 10. Conclusion

**Infrastructure Readiness**: MODERATE

**Strengths**:
- Rust SDK is production-ready
- Multi-owner chains supported natively
- Cross-chain messaging enables coordination

**Weaknesses**:
- Wallet integration uncertain
- Limited SDK options (Rust only)
- Emerging documentation

**Recommendation**: **PROCEED with PoC** to validate assumptions, particularly around wallet integration and testnet stability. Finalize architecture decisions after PoC completion.

---

**Next Document**: `linera-multisig-platform-proposal.md` - Complete proposal with architecture and hour estimates
