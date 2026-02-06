# Linera Multisig Platform - Deployment Blockers Analysis

> **Repository**: https://github.com/keyper-labs/linera.dev
> 
> 
> **Scope**: Multi-owner chain validation, Custom WASM contract deployment
> 
> **Objective**: Deploy a Safe-like multisig solution on Linera blockchain
> 

---

## Executive Summary

This document summarizes the results of a research initiative assessing whether a Safe-like multisig wallet can be implemented on Linera. The analysis began by evaluating Linera’s native **multi-owner chain** mechanism. Hands-on testing identified a core architectural limitation: 

the model operates as **1-of-N**, allowing any owner to execute actions unilaterally and immediately. While this behavior is effective for governance, it does not satisfy the **M-of-N threshold authorization** required for application-level asset custody.

Following this finding, the team developed a custom multisig contract in Rust implementing threshold enforcement, confirmation tracking, and proposal lifecycle management. The contract passed 74 validation tests covering compilation, security analysis, and SDK integration. Deployment to the Linera testnet encountered an "opcode 252" error indicating unsupported WASM instructions. Technical investigation revealed a circular dependency: linera-sdk 0.15.11 pins async-graphql 7.0.17, which requires Rust 1.87+, which generates memory.copy instructions (opcode 252) that the Linera runtime does not currently support. 

Multiple workarounds were attempted including code optimization, dependency patching, and a minimal contract experiment. Even stripping the contract to bare essentials (no cryptography, no history, minimal state) still produced 73 opcode 252 instances, indicating the issue originates in the SDK dependencies.

Investigation of the Linera GitHub repository identified issue #4742 documenting this compatibility consideration. The issue remains open pending protocol updates. Two gaps prevent Safe-like multisig deployment: 

1.- Linera's native multi-owner chain provides governance controls rather than threshold-based fund custody.

2.- Custom WASM contracts cannot deploy due to opcode 252 incompatibility, a protocol-level consideration tracked in issue #4742.

---

## Critical Deployment Blockers

### Blocker #1: Linera Multi-Owner Chain Lacks Multisig Semantics

**Problem Statement**

Linera's native multi-owner chain allows multiple owners to control a chain, but any single owner can execute operations without consensus or threshold validation. This is fundamentally different from a Safe-like multisig where M-of-N owners must approve transactions.

### Comparative Analysis: Safe-like Multisig vs. Linera Protocol

| Feature | Safe-like Multisig (Goal) | Linera Multi-Owner Chain (Current) | Match |
| --- | --- | --- | --- |
| Multiple owners | Yes | Yes | Yes |
| Threshold enforcement | M-of-N required | 1-of-N execution | No |
| Proposal submission | Submit, queue for approval | Execute immediately | No |
| Confirmation tracking | Track confirmations per owner | No confirmation counting | No |
| Proposal lifecycle | Submit, Confirm, Execute | Single step execution | No |
| Revoke confirmations | Can revoke before execution | No confirmation to revoke | No |
| Governance controls | Admin roles for changes | Any owner changes everything | No |
| Purpose | Application-level fund custody | Chain-level app deployment | Different |

**What Linera Provides**:

- Multiple owners can be assigned to a chain
- Any owner can submit operations
- No threshold enforcement (1-of-N can execute)
- No confirmation tracking (no multi-signature flow)
- No proposal lifecycle (submit, confirm, execute)

**What Safe-Like Multisig Requires**:

- Submit transaction proposals
- Track confirmations from multiple owners
- Enforce threshold before execution (M-of-N)
- Revoke confirmations
- Governance for owner changes

**Impact**: Linera's native feature cannot be used as a multisig wallet for secure asset management. It is designed for application deployment governance, not fund custody with threshold validation.

---

### Blocker #2: Opcode 252 - WASM Deployment Failure

**Reference**: [linera-protocol#4742](https://github.com/linera-io/linera-protocol/issues/4742)

**Problem Statement**

When attempting to deploy a custom multisig contract (to fill Gap #1), the Linera runtime rejects the compiled WASM binary due to unsupported `memory.copy` instructions (opcode 252).

**Error Details**:

```
Execution error: Invalid Wasm module: Unknown opcode 252 during Operation(0)
```

**Root Cause Analysis**:

```
Dependency Chain:
linera-sdk 0.15.11
  → async-graphql = "=7.0.17" (EXACT version required)
    → requires Rust 1.87+ (for `let` expressions in &&)
      → generates memory.copy (opcode 252)
        → Linera runtime rejects
```

**The Circular Dependency**:

| Component | Rust 1.86 | Rust 1.87+ |
| --- | --- | --- |
| WASM Compatible with Linera | Yes | No (opcode 252) |
| async-graphql 7.0.17 Compiles | No | Yes |
| linera-sdk 0.15.11 Works | No | Yes |

**Official Issue Status**:

- **Issue**: [#4742](https://github.com/linera-io/linera-protocol/issues/4742) - "Applications don't load with Rust 1.87 or later"
- **Reported**: October 6, 2025
- **Status**: Still Open
- **Linera Team Recommendation**: Use Rust 1.86 or earlier

**Related PR**:

- **PR #4894**: [Pin ruzstd to 0.8.1](https://github.com/linera-io/linera-protocol/pull/4894) - Fixes ruzstd 0.8.2 incompatibility with Rust 1.86
    - PR #4894 fixes a related compilation issue but does NOT resolve the opcode 252 blocker

**Why This Is A Blocker**:

- The multisig contract requires async-graphql for the query service
- async-graphql 7.0.17 requires Rust 1.87+
- Rust 1.87+ generates opcode 252
- Linera runtime does not support opcode 252

**Verification**:

```bash
# Compiled WASM contains 100+ instances of memory.copy
$ wasm-objdump -d multisig_contract.wasm | grep "fc 0a"
003248: fc 0a 00 00  |   memory.copy 0 0
004b92: fc 0a 00 00  |   memory.copy 0 0
...
```

**Impact**: Even though the contract compiles successfully and passes all validation tests, it cannot be deployed to the Linera testnet. This is a protocol-level limitation, not an application bug.

---

## Analysis of Proposed Solutions vs. Reality

Multiple approaches were explored to deploy a Safe-like multisig on Linera. Below are all documented attempts and their outcomes.

---

### Attempted Solution #1: Use Linera Multi-Owner Chain

**Proposal**: Use Linera's native multi-owner chain feature as the multisig solution.

**Reality**:

| Requirement | Linera Multi-Owner | Safe-Like Multisig | Match |
| --- | --- | --- | --- |
| Multiple owners | Yes | Yes | Yes |
| Threshold enforcement | No (1-of-N) | Yes (M-of-N) | No |
| Confirmation tracking | No | Yes | No |
| Proposal lifecycle | No | Yes | No |
| Revoke confirmations | No | Yes | No |

---

### Attempted Solution #2: Deploy Custom WASM Contract

**Proposal**: Build and deploy a custom multisig contract to provide Safe-like functionality.

**Reality**:

| Step | Expected | Actual | Status |
| --- | --- | --- | --- |
| Write contract code | Success | Success | Pass |
| Compile to WASM | Success | Success | Pass |
| Validate with scripts | Success | All tests pass | Pass |
| Deploy to testnet | Success | Opcode 252 error | Fail |

---

### Attempted Solution #3: Threshold Signatures Experiment

**Proposal**: Build a minimal contract without complex dependencies to avoid opcode 252.

**Location**: `experiments/threshold-signatures/`

**Modifications Made**:

- Removed `ed25519-dalek` (no cryptographic verification)
- Removed proposal history tracking
- Removed GraphQL operations (kept only ABI)
- Maintained: owners list, threshold, nonce, aggregate_key

**Result**:

```
Wasm Size: ~292 KB
Opcode 252 (memory.copy): 73 instances detected
Compilation: Successful
Deployment: WOULD FAIL on Linera testnet
```

**Finding**: Even with an extremely simplified contract, the Wasm bytecode still contains opcode 252. The problem is not in the contract code but in `linera-sdk` dependencies.

---

### Attempted Solution #4-10: Failed Workarounds for Opcode 252

Multiple technical workarounds were attempted to eliminate opcode 252 from the compiled WASM:

| # | Workaround Attempted | Result | Opcode Count |
| --- | --- | --- | --- |
| 4 | Remove `.clone()` calls | Broke mutability patterns | N/A |
| 5 | Remove proposal history | Reduced but still present | 85 opcodes |
| 6 | Remove GraphQL service | Reduced but still present | 82 opcodes |
| 7 | Use Rust 1.86.0 | async-graphql won't compile | N/A |
| 8 | Patch async-graphql version | Exact pin cannot override | N/A |
| 9 | Replace with async-graphql 6.x | Incompatible with linera-sdk 0.15.11 | N/A |
| 10 | Combined all optimizations | Best reduction achieved | 67 opcodes |

**Analysis**:

- 67 opcodes was the minimum achieved after applying ALL optimizations
- Any contract using linera-sdk generates opcode 252
- The circular dependency is unresolvable without SDK changes

**Conclusion**: All workarounds failed. Blocker requires protocol-level fix from Linera team.

---

### Summary of All Attempts

```
Attempt 1: Multi-Owner Chain
    └── Result: Does not provide Safe-like functionality

Attempt 2: Custom WASM Contract
    └── Result: Compiles but blocked by opcode 252

Attempt 3: Threshold Signatures (minimal contract)
    └── Result: Still 73 opcodes - blocker in SDK

Attempts 4-10: Technical workarounds
    ├── Remove clones, history, GraphQL
    ├── Rust version changes
    ├── Dependency patching
    └── Combined optimizations
        └── Result: 67 opcodes minimum, still blocked
```

**Final Assessment**: Under current Linera runtime constraints (as documented in Issue #4742), deploying a Safe-like multisig is not viable pending protocol updates.

---

## Gap Analysis Summary

### Protocol-Level Multisig Gap

**What Linera Provides**:

- Multi-owner chains for deployment governance
- Single-signature execution model
- Chain-level ownership

**What We Need**:

- Application-level multisig with thresholds
- M-of-N signature validation
- Proposal-based transaction flow
- Safe-like security model

**Gap Severity**: FUNDAMENTAL - Would require protocol-level changes or a completely different approach.

---

### Contract Deployment Gap

**What Linera Supports**:

- Simple WASM contracts (counter examples)
- Contracts without async-graphql
- Rust 1.86 or earlier

**What Our Multisig Requires**:

- Complex contract with GraphQL service
- async-graphql 7.0.17 (for query interface)
- Modern Rust (for dependencies)

**Gap Severity**: TECHNICAL BLOCKER - Currently prevents any complex contract deployment.

---

## Impact Assessment

### For Testnet POC

| Blocker | Impact | Resolution Required |
| --- | --- | --- |
| No multisig semantics | Critical | Protocol-level changes or different approach |
| Opcode 252 constraint | Critical | Resolution of Issue #4742 |

**Verdict**: Under current constraints, multisig POC deployment is not viable.

---

## Conclusion

### Central Finding

The attempt to deploy a Safe-like multisig on Linera revealed two architectural divergences:

1. **Multi-owner chain semantics** - Linera's native implementation provides chain governance (1-of-N execution) rather than application-level fund custody with M-of-N threshold requirements.
2. **WASM runtime compatibility** - Under current Linera runtime constraints (Issue #4742), contracts compiled with modern Rust toolchains encounter opcode 252 incompatibilities.

### Current State

| Aspect | Status |
| --- | --- |
| Custom multisig contract | Built and validated |
| Contract functionality | All 8 operations implemented |
| Contract security | Proper authorization and validation |
| Contract deployment | Blocked by opcode 252 |
| Testnet deployment | Not possible |
| Production readiness | Not possible |

### Recommendations

1. **For Linera Protocol Team**:
    - Prioritize resolution of Issue #4742 (opcode 252 support)
    - Consider native multisig support at protocol level
    - Document WASM limitations clearly

---

## References

### GitHub Issues & PRs

- **Issue #4742**: [Applications don't load with Rust 1.87 or later (opcode 252)](https://github.com/linera-io/linera-protocol/issues/4742)
- **PR #4894**: [Pin ruzstd to 0.8.1 for Rust 1.86 compatibility](https://github.com/linera-io/linera-protocol/pull/4894)
    - PR #4894 fixes a related compilation issue but does NOT resolve opcode 252 blocker

### Repository Documentation

- **Source Code**: `scripts/multisig-app/src/`
- **Validation Scripts**: `scripts/multisig/validate-multisig-complete.sh`
- **Contract Documentation**: `docs/multisig-custom/`
- **Architecture Analysis**: `docs/multisig-custom/ARCHITECTURE.md`
- **Threshold Signatures Experiment**: `experiments/threshold-signatures/`
- **Gap Analysis Table**: See "Gap Analysis" section in [ARCHITECTURE.md](http://architecture.md/)