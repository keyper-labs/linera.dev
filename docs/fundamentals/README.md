# Linera Fundamentals

Core concepts and architecture of the Linera blockchain platform.

## Overview

Linera is a multi-chain blockchain platform designed for web-scale applications. Unlike traditional single-chain blockchains, Linera enables each user to have their own lightweight chain (microchain) while sharing security through a common validator set.

## Key Concepts

| Concept | Description | Documentation |
|---------|-------------|---------------|
| **Microchains** | Lightweight chains per user/application | [microchains.md](./microchains.md) |
| **Applications** | WebAssembly smart contracts with dual-binary model | [applications.md](./applications.md) |
| **Ownership** | Chain ownership semantics and consensus modes | [ownership.md](./ownership.md) |
| **Messaging** | Cross-chain communication patterns | [messaging.md](./messaging.md) |

## Architecture Principles

```
┌─────────────────────────────────────────────────────────────────┐
│                    LINERA ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PRINCIPLE 1: MULTI-CHAIN OVER SINGLE-CHAIN                     │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐               │
│  │ Chain 1 │ │ Chain 2 │ │ Chain 3 │ │ Chain N │               │
│  │ (User)  │ │ (User)  │ │ (App)   │ │ (App)   │               │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘               │
│       └───────────┴───────────┴───────────┘                     │
│                   │                                             │
│                   ▼                                             │
│         ┌─────────────────┐                                     │
│         │ Shared Validator│  One validator set secures all      │
│         │ Network         │                                     │
│         └─────────────────┘                                     │
│                                                                  │
│  PRINCIPLE 2: USER-CHAIN AFFINITY                               │
│  • Each user typically owns their own chain                      │
│  • Low latency for user operations                               │
│  • No global contention (unlike single-chain)                    │
│                                                                  │
│  PRINCIPLE 3: ASYNC CROSS-CHAIN MESSAGING                       │
│  • Messages between chains are asynchronous                      │
│  • Inbox/outbox model for reliability                            │
│  • Applications can compose across chains                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

New to Linera? Start here:

1. **[Microchains](./microchains.md)** - Understand the core chain types and their properties
2. **[Applications](./applications.md)** - Learn about the contract/service dual-binary model
3. **[Ownership](./ownership.md)** - Explore chain ownership and consensus mechanisms
4. **[Messaging](./messaging.md)** - Master cross-chain communication patterns

## Comparison with Other Platforms

| Feature | Linera | Traditional Blockchain | Layer 2 |
|---------|--------|------------------------|---------|
| **Architecture** | Multi-chain | Single-chain | Rollup/Validium |
| **Scalability** | Horizontal (add chains) | Vertical (bigger blocks) | Off-chain |
| **Latency** | Low (single-owner chains) | Higher (global consensus) | Varies |
| **User Model** | Per-user chains | Shared global state | Varies |
| **Security** | Shared validators | Own validators | Inherited from L1 |

## Key Terminology

| Term | Definition |
|------|------------|
| **Microchain** | A lightweight blockchain with minimal overhead |
| **Validator** | Node that validates and executes blocks |
| **Worker** | Subset of validator handling specific chains |
| **Operation** | User-initiated state change on same chain |
| **Message** | Cross-chain communication |
| **Inbox/Outbox** | Queues for reliable message delivery |
| **Contract** | Gas-metered Wasm binary handling state changes |
| **Service** | Non-metered Wasm binary handling queries |

---

## Related Documentation

- [SDK Reference](../sdk/)
- [API Documentation](../api/)
- [Architecture Diagrams](../diagrams/)
