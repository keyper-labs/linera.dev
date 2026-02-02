# Linera Multisig Platform Proposal (Frontend + Backend)

**Document scope**: objectives, architecture, milestones, deliverables, risks, and dependencies for a production-ready multisig platform on Linera blockchain, leveraging multi-owner chains and cross-chain messaging.

---

## 1) Objectives - Deliver a production-ready multisig platform on Linera with professional UX and clear interface
- Build on Linera's **multi-owner chain** infrastructure with **application-level threshold logic**
- Provide simple proposal/review/execute workflow for non-technical users
- Support Linera native tokens and fungible applications
- Enable multi-multisig wallet management from single interface
- Real-time transaction status monitoring leveraging Linera's sub-second finality
- **Web wallet connector** integration (if available) or standalone web application

---

## 2) In-Scope

### Frontend (React/Next.js)
- Web application with wallet connector (if Linera wallet exists) OR standalone app
- **Wallet integration**: Manual key entry or QR code if no wallet connector available
- Multisig wallet creation wizard (2-of-3, 3-of-5, custom thresholds)
- Proposal builder with visual transaction interface
- Owner management (add/remove signatories)
- Transaction queue (pending approvals, executed, expired)
- Real-time updates via WebSocket (leveraging Linera's push notifications)
- Responsive design for desktop and mobile
- Error states and user-friendly notifications

### Backend (FastAPI)
- REST API for multisig operations
- PostgreSQL database (proposals, approvals, wallet metadata)
- Redis for caching and rate limiting
- **Linera SDK integration** (Rust SDK via FFI or Python bindings)
- **Multisig application management**: Deploy and interact with custom multisig smart contract
- Proposal lifecycle management
- WebSocket server for real-time updates
- Cross-chain message coordination

### Core Features
- **Multi-Owner Chain Creation**: Deploy chains with N owners for multisig wallets
- **Multisig Smart Contract**: Custom Wasm application implementing m-of-n threshold logic
- **Proposal System**: Create, review, sign, and execute multisig transactions
- **Token Support**: Linera native tokens and fungible applications
- **Threshold Management**: Configurable signature requirements
- **Cross-Chain Coordination**: Leverage Linera's messaging for owner notifications
- **History Tracking**: Complete audit trail of all multisig activities

### Security
- Ed25519 signature verification (Linera's signature scheme)
- Nonce/replay protection
- Application-level access control (verify owner membership)
- Rate limiting on all endpoints
- Secure key handling (keys never stored on server)
- CORS protection
- Threshold verification before execution

### DevOps & Monitoring
- GitHub Actions CI/CD pipeline
- Unit and integration tests
- Health check endpoints
- Basic monitoring setup (metrics, logging)

---

## 3) Out-of-Scope - Cross-chain bridges (Bitcoin, Ethereum, etc.)
- EVM support (planned for Q2'25, not available)
- Hardware wallet integration (future phase)
- Mobile native apps (responsive web only)
- Advanced DeFi features (liquidity, trading, derivatives)
- Custody/KYC/AML flows
- Formal security audits (prepare for later)
- Mobile push notifications (web notifications only)
- Social recovery or timelock features (Phase 2)

---

## 4) Architecture

### Architecture Goals

- **Linera-Native**: Leverage unique microchain architecture
- **Self-Custody**: Users control their private keys
- **Application-Level Multisig**: Smart contract with m-of-n threshold logic
- **Real-time**: Live updates leveraging Linera's sub-second finality and push notifications
- **Secure**: Best practices for key management and transaction validation
- **Cross-Chain Coordination**: Use Linera's messaging for owner notifications

### System Architecture ```mermaid
graph TB
    subgraph "Frontend (React/Next.js)"
        UI[User Interface]
        Wallet[Wallet Connector<br/>or Manual Key Entry]
        Wizard[Wallet Creation Wizard]
        Proposal[Proposal Builder]
        Dashboard[Dashboard]
        Queue[Transaction Queue<br/>Pending Approvals]
    end

    subgraph "Backend (Python/FastAPI)"
        API[REST API]
        MultisigSvc[Multisig Service<br/>Contract Management]
        ProposalSvc[Proposal Service<br/>Lifecycle Management]
        BlockchainSvc[Blockchain Integration<br/>Linera SDK]
        MessageSvc[Message Service<br/>Cross-Chain Coordination]
        NotificationSvc[Notification Service<br/>Push Updates]
    end

    subgraph "Linera Network"
        Validators[Linera Validators<br/>Shared Security]
        UserChains[User Chains<br/>Owner Wallets]
        MultiChain[Multi-Owner Chain<br/>Multisig Wallet]
        Contract[Multisig Application<br/>Wasm Bytecode]
        Inboxes[Cross-Chain Inboxes<br/>Message Routing]
    end

    subgraph "Storage"
        Postgres[(PostgreSQL<br/>Wallets, Proposals<br/>Approvals, Metadata)]
        Redis[(Redis<br/>Cache, Rate Limits<br/>Message Queue)]
    end

    UI --> Wallet
    UI --> Wizard
    UI --> Proposal
    UI --> Dashboard
    UI --> Queue
    UI --> API
    Wizard --> API
    Proposal --> API
    Queue --> API

    API --> MultisigSvc
    API --> ProposalSvc
    API --> BlockchainSvc
    API --> MessageSvc
    API --> NotificationSvc

    MultisigSvc --> BlockchainSvc
    ProposalSvc --> Postgres
    MessageSvc --> Inboxes
    NotificationSvc --> Inboxes

    BlockchainSvc --> Validators
    BlockchainSvc --> UserChains
    BlockchainSvc --> MultiChain
    MultisigSvc --> Contract

    Validators --> UserChains
    Validators --> MultiChain
    UserChains --> Inboxes
    MultiChain --> Inboxes
    BlockchainSvc --> Redis
    API --> Redis

    style UI fill:#e1f5fe
    style Wallet fill:#e1f5fe
    style MultiChain fill:#c8e6c9
    style Contract fill:#c8e6c9
    style Inboxes fill:#fff9c4
    style Validators fill:#fff9c4
``` ### Linera Integration Approach **Important**: Linera's multisig approach differs from traditional chains: **Primary Method: Application-Level Multisig on Multi-Owner Chains**
- Deploy multi-owner chain with N owners
- Deploy custom Wasm multisig application
- Application implements m-of-n threshold logic
- Owners propose transactions via operations
- Other owners approve via application operations
- Execution occurs when threshold met **Key Integration Points**:
1. **Multi-Owner Chain Creation**: Use Linera SDK to create chains with multiple owners
2. **Smart Contract Deployment**: Deploy multisig Wasm bytecode
3. **Operation Submission**: Owners create blocks with operations
4. **Cross-Chain Messaging**: Notify owners of pending approvals
5. **State Queries**: Read application state for approvals/transactions **Wallet Integration**:
- **If Linera wallet exists**: Integrate via wallet connector
- **If no wallet**: Manual key entry or QR code signing
- **Future**: Browser extension when available **Cryptographic Scheme**:
- **Signature Scheme**: Ed25519 (Linera's standard)
- **Chain Ownership**: N owners with individual key pairs
- **Authentication**: Block signer authentication propagates via messages
- **Application-Level Authorization**: Custom logic in multisig contract

### Key Flow: Propose → Approve → Execute ```mermaid
sequenceDiagram
    participant O1 as Owner 1
    participant O2 as Owner 2
    participant O3 as Owner 3
    participant UI as Frontend
    participant API as Backend
    participant SC as Multisig Contract
    participant LC as Linera Chain

    O1->>UI: Create transaction proposal
    UI->>API: POST /propose (tx_data, signature)
    API->>SC: CreateProposal operation
    SC->>LC: Execute on multi-owner chain
    LC-->>SC: Proposal created (approvals: [O1])
    SC->>LC: Send approval notification to O2, O3
    API-->>UI: Proposal ID, status: pending

    Note over O2,O3: Cross-chain messages delivered to owner chains

    O2->>UI: View proposal, approve
    UI->>API: POST /approve (proposal_id, signature)
    API->>SC: ApproveProposal operation
    SC->>LC: Execute on multi-owner chain
    LC-->>SC: Approval recorded (approvals: [O1, O2])
    SC->>LC: Send notification to O3
    API-->>UI: Status updated

    O3->>UI: View proposal, approve
    UI->>API: POST /approve (proposal_id, signature)
    API->>SC: ApproveProposal operation
    SC->>LC: Execute on multi-owner chain
    LC-->>SC: Approval recorded (approvals: [O1, O2, O3])
    SC->>SC: Check threshold: 3-of-3 met ✓
    API-->>UI: Status: ready_to_execute

    O1->>UI: Execute transaction
    UI->>API: POST /execute (proposal_id, signature)
    API->>SC: ExecuteProposal operation
    SC->>LC: Execute inner transaction
    LC-->>SC: Transaction executed
    API-->>UI: Status: executed
    SC->>LC: Send completion notifications
``` **Key Differences from Traditional Multisig**:
- No signature aggregation at protocol level
- Each approval is a separate on-chain operation
- Application tracks approvals in state
- Threshold verification in contract logic
- Leverages Linera's cross-chain messaging for coordination

---

## 5) Milestones & Deliverables ### Timeline Overview ```mermaid
gantt
    dateFormat YYYY-MM-DD
    title Linera Multisig Platform Delivery Timeline

    section Foundations
    M1 Project Setup (40h)           :done,    m1, 2026-02-03, 5d

    section Smart Contract
    M2 Multisig Contract (120h)      :active,  m2, 2026-02-10, 15d

    section Backend
    M3 Backend Core (150h)           :         m3, 2026-02-27, 19d

    section Frontend
    M4 Frontend Core (120h)          :crit,    m4, 2026-03-20, 15d

    section Integration
    M5 Integration & Testing (80h)   :         m5, 2026-04-06, 10d

    section Ops/Obs
    M6 Observability & Hardening (40h) :        m6, 2026-04-18, 5d

    section QA
    M7 QA & UAT (40h)                :         m7, 2026-04-25, 5d

    section Handoff
    M8 Handoff (20h)                 :         m8, 2026-05-02, 3d
```

*Note: Timeline assumes 8-hour workdays. Total: ~10-11 weeks.*

### Detailed Milestone Breakdown #### M1 Project Setup — 40h **Tasks**:
- Requirements definition and refinement (8h)
- Architecture design and documentation (8h)
- Development environment setup (4h)
- Linera testnet access and configuration (8h)
- CI/CD pipeline setup (GitHub Actions) (4h)
- Database schema design (4h)
- API contract definition (4h) **Deliverables**:
- Requirements document
- System architecture diagrams
- Development environments configured
- CI/CD pipeline operational
- Database schema finalized
- API endpoints documented

---

#### M2 Multisig Smart Contract — 120h **Tasks**: | Task | Hours | Description |
|------|-------|-------------|
| Contract State Design | 16h | Define structures for owners, threshold, pending txs, approvals |
| Propose Operation | 16h | Implement transaction proposal with validation |
| Approve Operation | 12h | Implement approval tracking and verification |
| Execute Operation | 20h | Implement threshold check and inner tx execution |
| Owner Management | 12h | Add/remove owners, change threshold |
| Edge Cases | 16h | Revoke, replace, timeout, cancellation |
| Unit Tests | 16h | Comprehensive test coverage |
| Integration Tests | 12h | Test with Linera SDK and testnet | **Deliverables**:
- Multisig Wasm application bytecode
- Comprehensive unit test suite
- Integration tests with Linera testnet
- Contract documentation and API
- Security review checklist

**Complexity**: High - custom application-level multisig logic

---

#### M3 Backend Core — 150h **Tasks**: | Task | Hours | Description |
|------|-------|-------------|
| API Framework Setup | 12h | FastAPI project structure, middleware |
| Linera SDK Integration | 30h | FFI or Python bindings, chain operations |
| Multisig Service | 24h | Contract deployment, interaction |
| Proposal Service | 20h | CRUD operations, lifecycle management |
| Message Service | 16h | Cross-chain notification handling |
| Database Layer | 18h | SQLAlchemy models, migrations |
| Caching & Rate Limiting | 10h | Redis integration |
| Authentication | 10h | Ed25519 signature verification |
| WebSocket Server | 10h | Real-time updates |
| Unit Tests | 10h | Service-level tests | **Deliverables**:
- REST API with all endpoints
- Linera SDK integration
- PostgreSQL database with migrations
- Redis caching and rate limiting
- WebSocket server for real-time updates
- Comprehensive test suite

**Complexity**: High - Linera SDK integration and custom multisig logic

---

#### M4 Frontend Core — 120h **Tasks**: | Task | Hours | Description |
|------|-------|-------------|
| Project Setup | 8h | Next.js, TypeScript, state management |
| Wallet Integration | 24h | Manual key entry or QR code (if no connector) |
| Wallet Creation Wizard | 16h | Multi-step form, threshold selection |
| Proposal Builder | 16h | Visual transaction builder |
| Transaction Queue | 16h | Pending, ready, executed tabs |
| Real-time Updates | 12h | WebSocket integration |
| Dashboard | 12h | Wallet overview, activity feed |
| Error Handling | 8h | User-friendly error messages |
| Unit Tests | 8h | Component and service tests | **Deliverables**:
- Responsive web application
- Wallet integration (manual or connector)
- Multisig creation wizard
- Proposal builder interface
- Transaction queue with real-time updates
- Comprehensive test suite

**Complexity**: Medium - wallet integration challenges

---

#### M5 Integration & Testing — 80h **Tasks**: | Task | Hours | Description |
|------|-------|-------------|
| End-to-End Integration | 20h | Frontend → Backend → Blockchain |
| Cross-Chain Messaging | 12h | Owner notification flow |
| Multi-Owner Testing | 16h | Simulate multiple owners |
| Edge Case Testing | 12h | Failure scenarios, timeouts |
| Performance Testing | 8h | Load testing, latency checks |
| Bug Fixes | 12h | Address integration issues | **Deliverables**:
- Fully integrated platform
- End-to-end test scenarios
- Performance benchmarks
- Bug fixes and refinements

**Complexity**: High - multi-owner coordination testing

---

#### M6 Observability & Hardening — 40h **Tasks**: | Task | Hours | Description |
|------|-------|-------------|
| Metrics | 12h | Prometheus metrics, Grafana dashboards |
| Logging | 8h | Structured logging, Loki integration |
| Health Checks | 6h | API health, blockchain connectivity |
| Rate Limiting Tuning | 6h | Optimize rate limits |
| Security Hardening | 8h | Input validation, CORS, headers | **Deliverables**:
- Monitoring dashboards
- Structured logging
- Health check endpoints
- Security hardening applied

---

#### M7 QA & UAT — 40h **Tasks**: | Task | Hours | Description |
|------|-------|-------------|
| Test Scenarios | 16h | Multi-owner, timeout, failures |
| Regression Testing | 8h | Ensure no regressions |
| User Acceptance Testing | 12h | Real-world usage scenarios |
| Bug Fixes | 4h | Address QA findings | **Deliverables**:
- Comprehensive test report
- UAT sign-off
- Bug fixes applied

---

#### M8 Handoff — 20h **Tasks**: | Task | Hours | Description |
|------|-------|-------------|
| Documentation | 8h | API docs, deployment guides |
| Demos | 4h | Stakeholder demonstrations |
| Runbooks | 4h | Operations, DR, rollback |
| Final Handoff | 4h | Knowledge transfer | **Deliverables**:
- API documentation
- Deployment guides
- Operations runbooks
- Final demo and handoff

---

**Total estimate: 610h**

---

## 6) Technical Implementation

### Smart Contract Interface (Rust Pseudo-code) ```rust
// Multisig application state
struct MultisigState {
    owners: Vec<Owner>,
    threshold: usize,
    pending_transactions: HashMap<TxId, PendingTx>,
    nonce: u64,
}

struct PendingTx {
    proposer: Owner,
    operations: Vec<Operation>,
    approvals: HashSet<Owner>,
    created_at: Timestamp,
    expires_at: Option<Timestamp>,
}

// Application operations
enum Operation {
    Propose {
        operations: Vec<Operation>,
        nonce: u64,
        timeout: Option<Duration>,
    },
    Approve { tx_id: TxId },
    Revoke { tx_id: TxId },
    Execute { tx_id: TxId },
    AddOwner {
        owner: Owner,
        threshold: Option<usize>,
    },
    RemoveOwner {
        owner: Owner,
        threshold: Option<usize>,
    },
    ChangeThreshold { threshold: usize },
}
```

### Database Schema

```sql
-- Multisig wallets
CREATE TABLE wallets (
    id UUID PRIMARY KEY,
    chain_id VARCHAR(255) UNIQUE NOT NULL,
    application_id VARCHAR(255) NOT NULL,
    owners JSONB NOT NULL, -- Array of owner addresses
    threshold INTEGER NOT NULL,
    nonce BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Pending proposals
CREATE TABLE proposals (
    id UUID PRIMARY KEY,
    wallet_id UUID REFERENCES wallets(id),
    proposal_id VARCHAR(255) NOT NULL,
    proposer VARCHAR(255) NOT NULL,
    operations JSONB NOT NULL,
    approvals JSONB DEFAULT '[]', -- Array of owner addresses
    threshold_met BOOLEAN DEFAULT FALSE,
    status VARCHAR(50) DEFAULT 'pending', -- pending, ready, executed, expired, revoked
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    executed_at TIMESTAMP,
    UNIQUE(wallet_id, proposal_id)
);

-- Approvals (for faster queries)
CREATE TABLE approvals (
    id UUID PRIMARY KEY,
    proposal_id UUID REFERENCES proposals(id),
    owner VARCHAR(255) NOT NULL,
    signature TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(proposal_id, owner)
);

-- Audit log
CREATE TABLE audit_log (
    id UUID PRIMARY KEY,
    wallet_id UUID REFERENCES wallets(id),
    proposal_id UUID REFERENCES proposals(id),
    owner VARCHAR(255) NOT NULL,
    action VARCHAR(100) NOT NULL,
    details JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### Key API Endpoints

```http
# Wallet Management
POST   /api/v1/wallets                     - Create new multisig wallet
GET    /api/v1/wallets                     - List user's wallets
GET    /api/v1/wallets/:wallet_id          - Get wallet details
PUT    /api/v1/wallets/:wallet_id/owners   - Add/remove owners
PUT    /api/v1/wallets/:wallet_id/threshold - Change threshold

# Proposal Management
POST   /api/v1/wallets/:wallet_id/proposals       - Create proposal
GET    /api/v1/wallets/:wallet_id/proposals       - List proposals
GET    /api/v1/proposals/:proposal_id             - Get proposal details
POST   /api/v1/proposals/:proposal_id/approve     - Approve proposal
POST   /api/v1/proposals/:proposal_id/revoke      - Revoke proposal
POST   /api/v1/proposals/:proposal_id/execute     - Execute proposal

# WebSocket
WS     /api/v1/ws                             - Real-time updates

# Health
GET    /health                               - Health check
GET    /metrics                              - Prometheus metrics
```

---

## 7) Testing Strategy ### Testing Levels **Unit Tests**:
- Smart contract operations (propose, approve, execute)
- Backend service logic
- Frontend components
- Signature verification **Integration Tests**:
- Backend + Linera testnet
- Frontend + Backend API
- Cross-chain messaging
- Database operations **End-to-End Tests**:
- Complete multisig workflows
- Multi-owner scenarios
- Edge cases (timeout, revoke, failure)

### Test Scenarios **Happy Path**:
1. Create 2-of-3 multisig wallet
2. Owner 1 proposes transfer
3. Owner 2 approves
4. Owner 3 approves
5. Owner 1 executes
6. Verify transaction executed **Edge Cases**:
1. Proposal timeout (expires before threshold)
2. Revoke proposal (cancel before execution)
3. Execute without threshold (should fail)
4. Duplicate approval (should be idempotent)
5. Non-owner approval (should fail)
6. Remove owner with pending proposals **Failure Scenarios**:
1. Network failure during approval
2. Invalid signature
3. Insufficient balance
4. Contract execution failure

---

## 8) Risks & Mitigations

| Risk | Mitigation | Priority |
|------|------------|----------|
| **No native multisig** - Must implement custom contract | Thorough testing, external audit, start with simple m-of-n | **High** |
| **Wallet integration** - May not have connector | Plan for manual key entry, QR code fallback | **High** |
| **SDK immaturity** - Limited documentation/examples | Budget for research, Linera community support | **Medium** |
| **Testnet stability** - May be unstable | Budget for debugging, contingency time | **Medium** |
| **Cross-chain complexity** - Message delivery failures | Comprehensive error handling, retry logic, monitoring | **Medium** |
| **Smart contract bugs** - Security vulnerabilities | External audit, bug bounty, formal verification if possible | **High** |
| **Gas costs** - Multiple operations expensive | Optimize operations, batch approvals | **Low** |
| **User experience** - Complex multisig flow | Clear UI, explicit guidance, tooltips | **Medium** |

---

## 9) Dependencies ### External Dependencies **Blockchain**:
- Linera testnet access and stability
- Linera Rust SDK maturity
- Documentation completeness **Wallet**:
- Linera web wallet (if exists) OR manual key entry
- Browser compatibility **Infrastructure**:
- PostgreSQL database
- Redis cache
- Hosting provider (Vercel/AWS/etc.) ### Team Requirements **Must Have**:
- Senior Rust developer (smart contract)
- Backend developer (Python/FastAPI)
- Frontend developer (React/Next.js)
- DevOps engineer **Nice to Have**:
- Security auditor
- Linera ecosystem expert

---

## 10) Next Steps **Immediate Actions** (Week 1): 1. **Verify Linera Testnet Access**: Ensure testnet is stable and accessible
2. **Research SDK Documentation**: Deep dive into Linera Rust SDK
3. **Explore Wallet Options**: Check if Linera wallet exists, evaluate alternatives
4. **Proof of Concept**: Build minimal multisig contract on testnet
5. **Refine Hour Estimates**: After PoC, adjust estimates based on findings
6. **Assemble Team**: Hire/assign developers for each role
7. **Security Planning**: Identify auditors, plan for review **Decision Points**:
- After PoC (Week 2): Confirm feasibility or pivot approach
- After M2 (Week 5): Review contract and approve for backend integration
- After M4 (Week 10): UX review and refinement

---

## Comparison with Reference Projects

| Aspect | Hathor (320h) | Supra (446h) | Linera (610h) |
|--------|---------------|--------------|---------------|
| **Multisig Type** | Native P2SH | Native module | Application-level |
| **Wallet Integration** | Headless Wallet | StarKey | Manual/QR (unknown) |
| **Smart Contract** | None | None | Custom Wasm app |
| **SDK Maturity** | Mature | Mature | Emerging |
| **Documentation** | Good | Good | Limited |
| **Complexity** | Medium | Medium | High |
| **Testing** | Standard | Extensive | Extensive | **Why Linera is Higher**:
- Custom smart contract development (+120h)
- Application-level multisig logic (more complex than native)
- Less mature SDK (more research/learning)
- Unknown wallet integration (may need custom)
- Cross-chain messaging coordination

---

## Conclusion

**Feasibility**: **FEASIBLE** with custom implementation **Key Considerations**:
- No native multisig - must implement smart contract
- Higher complexity than Hathor/Supra
- Leverages Linera's unique multi-owner chains
- Cross-chain messaging enables coordination
- Sub-second finality improves UX
- Wallet integration uncertain **Recommendation**: **PROCEED** with proof of concept to validate assumptions, then commit to full development.

**Total Effort**: 610 hours (~15 weeks with 1 FTE or ~8 weeks with 2 FTEs)

---

**Produced by Palmera DAO Team**
**Date**: February 2, 2026
