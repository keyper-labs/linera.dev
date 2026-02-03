# Linera gRPC API

Low-level RPC interface for direct validator communication.

## Overview

The gRPC API provides direct access to Linera validators for backend integration. It's used by the `linera-client` and `linera-core` crates internally.

## Service Definitions

### ValidatorNode Service

Main service for client-validator communication.

```protobuf
service ValidatorNode {
  // Propose a new block
  rpc HandleBlockProposal(BlockProposal) returns (ChainInfoResponse);
  
  // Process confirmed certificate
  rpc HandleCertificate(Certificate) returns (ChainInfoResponse);
  
  // Process lite certificate (acknowledgment)
  rpc HandleLiteCertificate(LiteCertificate) returns (ChainInfoResponse);
  
  // Query chain information
  rpc HandleChainInfoQuery(ChainInfoQuery) returns (ChainInfoResponse);
}
```

### Notifier Service

Service for receiving chain updates.

```protobuf
service NotifierService {
  // Subscribe to chain updates
  rpc Subscribe(SubscriptionRequest) returns (stream Notification);
}
```

## Key Methods

### HandleBlockProposal

Submit a new block proposal to the validator.

```rust
let response = client
    .handle_block_proposal(block_proposal)
    .await?;
```

### HandleCertificate

Submit a confirmed certificate after block validation.

```rust
let response = client
    .handle_certificate(certificate)
    .await?;
```

### HandleChainInfoQuery

Query information about a chain.

```rust
let query = ChainInfoQuery::new(chain_id);
let info = client
    .handle_chain_info_query(query)
    .await?;
```

## Rust Integration

### Using linera-rpc

```rust
use linera_rpc::RpcClient;
use linera_core::client::Client;

// Create RPC client
let client = RpcClient::new(
    "validator.testnet-conway.linera.net:443"
)?;

// Query chain information
let info = client
    .handle_chain_info_query(ChainInfoQuery::new(chain_id))
    .await?;
```

### Using linera-client

```rust
use linera_client::ClientContext;
use linera_core::client::ChainClient;

// Initialize context
let context = ClientContext::new(storage, options).await?;

// Get chain client
let mut chain_client = context.make_chain_client(chain_id)?;

// Operations use gRPC internally
let balance = chain_client.query_balance().await?;
```

## Protocol Definitions

### ChainInfoQuery

```rust
pub struct ChainInfoQuery {
    pub chain_id: ChainId,
    pub test_next_block_height: Option<BlockHeight>,
    pub request_owner_balance: Option<AccountOwner>,
    pub request_pending_messages: bool,
    pub request_received_messages_exceeding: Option<u64>,
}
```

### ChainInfoResponse

```rust
pub struct ChainInfoResponse {
    pub chain_id: ChainId,
    pub info: ChainInfo,
}

pub struct ChainInfo {
    pub chain_id: ChainId,
    pub next_block_height: BlockHeight,
    pub state_hash: CryptoHash,
    pub confirmed_log: Vec<CryptoHash>,
    pub request_count: u64,
}
```

## Message Types

### BlockProposal

```rust
pub struct BlockProposal {
    pub content: BlockProposalContent,
    pub owner: AccountOwner,
    pub signature: AccountSignature,
}

pub struct BlockProposalContent {
    pub block: Block,
    pub round: Round,
    pub validated_operations_certificate: Option<Certificate>,
}
```

### Certificate

```rust
pub struct Certificate {
    pub value: HashedCertificateValue,
    pub round: Round,
    pub signatures: Vec<(AccountOwner, AccountSignature)>,
}
```

## Network Endpoints

### Testnet Conway

```
validator-1.testnet-conway.linera.net:443
```

### Local Development

```
localhost:9100  # Default local validator port
```

## TLS Configuration

```rust
let tls_config = ClientTlsConfig::new()
    .domain_name("validator.testnet-conway.linera.net");

let channel = Channel::from_static("https://validator.testnet-conway.linera.net:443")
    .tls_config(tls_config)?
    .connect()
    .await?;
```

## Error Handling

### Common gRPC Errors

| Code | Meaning | Solution |
|------|---------|----------|
| `UNAVAILABLE` | Validator offline | Retry with backoff |
| `INVALID_ARGUMENT` | Invalid request | Check request format |
| `UNAUTHENTICATED` | Invalid signature | Verify signing key |
| `ALREADY_EXISTS` | Block already proposed | Wait for confirmation |
| `RESOURCE_EXHAUSTED` | Rate limited | Implement backoff |

### Error Handling Example

```rust
match client.handle_block_proposal(proposal).await {
    Ok(response) => Ok(response),
    Err(status) if status.code() == Code::Unavailable => {
        // Retry with exponential backoff
        tokio::time::sleep(Duration::from_secs(1)).await;
        client.handle_block_proposal(proposal).await
    }
    Err(status) => Err(status.into()),
}
```

## Performance Considerations

### Connection Pooling

```rust
use tonic::transport::{Channel, Endpoint};

// Create channel with connection pooling
let endpoint = Endpoint::from_static("https://validator.example.com:443")
    .keep_alive_while_idle(true)
    .keep_alive_timeout(Duration::from_secs(60));

let channel = endpoint.connect().await?;
```

### Batch Operations

```rust
// Batch multiple operations into single block
let operations = vec![op1, op2, op3];
let certificate = chain_client
    .execute_operations(operations, blobs)
    .await?;
```

## Security

### Authentication

All gRPC requests must be signed by the chain owner.

```rust
// Sign block proposal
let signature = account.sign(&proposal.content.hash());
let signed_proposal = BlockProposal {
    content: proposal.content,
    owner: account.owner(),
    signature,
};
```

### TLS Requirements

- Always use TLS in production
- Verify validator certificates
- Use certificate pinning for known validators

## Debugging

### Enable gRPC Logging

```bash
export RUST_LOG=linera_rpc=debug
```

### Request Tracing

```rust
use tracing::{info, instrument};

#[instrument]
async fn query_chain(
    client: &mut RpcClient,
    chain_id: ChainId
) -> Result<ChainInfo, Error> {
    info!(?chain_id, "Querying chain info");
    let query = ChainInfoQuery::new(chain_id);
    client.handle_chain_info_query(query).await
}
```

## Related Documentation

- [linera-rpc crate](https://docs.rs/linera-rpc/)
- [linera-core client](https://docs.rs/linera-core/)
- [Protocol Buffers](https://github.com/linera-io/linera-protocol/blob/main/linera-rpc/proto/rpc.proto)
