# Linera API Documentation

Complete API reference for building applications on the Linera blockchain.

## Overview

Linera provides multiple interfaces for interacting with the network:

| API Type | Purpose | Status | Documentation |
|----------|---------|--------|---------------|
| **GraphQL** | Read-only queries via Service |  Available | [GraphQL API](./graphql-api.md) |
| **gRPC** | Low-level validator communication |  Available | [gRPC API](./grpc-api.md) |
| **CLI** | Command-line wallet operations |  Available | [CLI Reference](./cli-reference.md) |
| **SDK (Rust)** | Application development |  Available | [SDK API](./sdk-api.md) |
| **@linera/client** | Frontend TypeScript SDK |  Available | [TypeScript SDK](./typescript-sdk.md) |
| **REST** | HTTP REST interface |  Custom Required | Build your own |

---

## Quick Reference

### Chain Operations

```rust
// Query balance
chain_client.query_balance().await?;

// Execute operation
chain_client.execute_operation(operation).await?;

// Transfer tokens
chain_client.transfer(amount, recipient).await?;
```

### GraphQL Queries

```graphql
# Query application state
query {
  application(id: "APP_ID") {
    state
  }
}
```

### CLI Commands

```bash
# Query balance
linera query-balance CHAIN_ID

# Transfer tokens
linera transfer 10 --from CHAIN1 --to CHAIN2

# Create multi-owner chain
linera open-multi-owner-chain --from CHAIN --owners OWNER1 OWNER2
```

---

## Document Index

### [GraphQL API](./graphql-api.md)
Service-side GraphQL interface for querying application state.

**Use for**: Reading application state, frontend data fetching

### [gRPC API](./grpc-api.md)
Low-level RPC interface for validator communication.

**Use for**: Backend integration, direct validator communication

### [CLI Reference](./cli-reference.md)
Complete command-line interface reference.

**Use for**: Wallet management, chain operations, deployment

### [SDK API](./sdk-api.md)
Rust SDK for building Linera applications.

**Use for**: Smart contract development, application logic

### [TypeScript SDK](./typescript-sdk.md)
Frontend SDK for browser-based applications.

**Use for**: Wallet integration, frontend blockchain interaction

---

## Architecture

```

                        Client Layer                          

   GraphQL       gRPC          CLI       @linera/client   
   (Read)      (Low-level) (Interactive)  (Frontend)      

                                           

                      
          
             Validator Node      
             (linera-service)    
          
                      
          
             Linera Network      
             (Microchains)       
          
```

---

## Choosing the Right API

### For Frontend Developers
Use **@linera/client** (TypeScript SDK)
- Wallet management
- Key generation and storage
- Chain queries
- Transaction signing

### For Backend Developers
Use **gRPC** or **linera-client** crate
- Direct validator communication
- High-performance operations
- Server-side integration

### For Application Developers
Use **linera-sdk** (Rust)
- Smart contract development
- Application logic
- State management

### For Data Fetching
Use **GraphQL** (via Service)
- Read-only queries
- Frontend state hydration
- Application data retrieval

---

## Version Information

| Component | Version | Last Updated |
|-----------|---------|--------------|
| linera-sdk | 0.15.11 | 2025-02-03 |
| linera-client | 0.15.11 | 2025-02-03 |
| linera-core | 0.15.11 | 2025-02-03 |
| @linera/client | 0.15.0 | 2025-02-03 |

---

## Network Endpoints

### Testnet Conway
- Faucet: `https://faucet.testnet-conway.linera.net`
- Validator: `validator-1.testnet-conway.linera.net:443`
- GraphQL: `http://localhost:8080` (local node service)

### Local Development
```bash
# Start local test network
linera net up --with-faucet --faucet-port 8080
```

---

## Additional Resources

- [Linera Developer Documentation](https://linera.dev)
- [Rust SDK Docs](https://docs.rs/linera-sdk/)
- [GitHub Repository](https://github.com/linera-io/linera-protocol)
- [Example Applications](https://github.com/linera-io/linera-protocol/tree/main/examples)
