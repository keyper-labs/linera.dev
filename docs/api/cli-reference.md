# Linera CLI Reference

Complete command-line interface for the Linera blockchain.

## Installation

```bash
# Build from source
git clone https://github.com/linera-io/linera-protocol.git
cd linera-protocol
cargo build --release -p linera-service

# Add to PATH
export PATH="$PWD/target/release:$PATH"
```

## Global Options

```bash
linera [OPTIONS] <COMMAND>

Options:
    --wallet <WALLET>           Path to wallet file [env: LINERA_WALLET]
    --keystore <KEYSTORE>       Path to keystore file [env: LINERA_KEYSTORE]
    --storage <STORAGE>         Storage configuration [env: LINERA_STORAGE]
    -h, --help                  Print help
```

## Wallet Commands

### wallet init

Initialize a new wallet.

```bash
linera wallet init [OPTIONS]

Options:
    --faucet <FAUCET>           Faucet URL for testnet
    --from-seed <SEED>          Initialize from seed phrase
    --with-new-chain            Create a new chain

Examples:
    # Initialize with testnet faucet
    linera wallet init --faucet https://faucet.testnet-conway.linera.net
    
    # Initialize from seed
    linera wallet init --from-seed "seed phrase here"
```

### wallet show

Display wallet contents.

```bash
linera wallet show [OPTIONS]

Options:
    --chain <CHAIN>             Show specific chain only
    --short                     Short format
```

### wallet request-chain

Request a new chain from faucet.

```bash
linera wallet request-chain --faucet <FAUCET_URL>

Example:
    linera wallet request-chain --faucet https://faucet.testnet-conway.linera.net
```

## Chain Commands

### open-chain

Open a new single-owner chain.

```bash
linera open-chain [OPTIONS]

Options:
    --from <CHAIN>              Parent chain (required)
    --to-public-key <KEY>       Public key for new chain
    --initial-balance <AMOUNT>  Initial balance

Example:
    linera open-chain --from CHAIN_ID --initial-balance 1000
```

### open-multi-owner-chain

Open a new multi-owner chain.

```bash
linera open-multi-owner-chain [OPTIONS]

Options:
    --from <CHAIN>              Parent chain (required)
    --owners <OWNERS>...        Owner public keys
    --initial-balance <AMOUNT>  Initial balance
    --multi-leader-rounds <N>   Number of multi-leader rounds

Example:
    linera open-multi-owner-chain \
        --from CHAIN1 \
        --owners OWNER1 OWNER2 OWNER3 \
        --initial-balance 1000 \
        --multi-leader-rounds 2
```

### close-chain

Close a chain permanently.

```bash
linera close-chain <CHAIN_ID>

Example:
    linera close-chain CHAIN_ID
```

### query-balance

Query chain or account balance.

```bash
linera query-balance [ACCOUNT@CHAIN]

Examples:
    # Query chain balance
    linera query-balance CHAIN_ID
    
    # Query account balance on chain
    linera query-balance ACCOUNT@CHAIN_ID
```

## Transfer Commands

### transfer

Transfer tokens between chains or accounts.

```bash
linera transfer <AMOUNT> --from <SOURCE> --to <DESTINATION>

Options:
    --from <SOURCE>             Source (chain or account@chain)
    --to <DESTINATION>          Destination (chain or account@chain)

Examples:
    # Transfer between chains
    linera transfer 10 --from CHAIN1 --to CHAIN2
    
    # Transfer to account
    linera transfer 5 --from CHAIN1 --to ACCOUNT@CHAIN2
    
    # Transfer from account
    linera transfer 3 --from ACCOUNT@CHAIN1 --to CHAIN2
```

## Application Commands

### publish-and-create

Publish bytecode and create application instance.

```bash
linera publish-and-create [OPTIONS] <CONTRACT> <SERVICE> [INIT_ARGS]

Arguments:
    <CONTRACT>                  Path to contract bytecode
    <SERVICE>                   Path to service bytecode
    [INIT_ARGS]                 Initialization arguments (JSON)

Options:
    --from <CHAIN>              Chain to publish on
    --json-argument <JSON>      JSON initialization argument
    --required-application <ID> Required application dependency

Example:
    linera publish-and-create \
        ./target/wasm32-unknown-unknown/release/my_contract.wasm \
        ./target/wasm32-unknown-unknown/release/my_service.wasm \
        --json-argument '{"initial_value": 0}'
```

### publish-module

Publish bytecode without creating instance.

```bash
linera publish-module <BYTECODE_PATH> --from <CHAIN>

Example:
    linera publish-module contract.wasm --from CHAIN_ID
```

### create-application

Create application instance from published bytecode.

```bash
linera create-application [OPTIONS] <BYTECODE_ID>

Options:
    --json-argument <JSON>      Initialization arguments
    --required-application <ID> Required application

Example:
    linera create-application BYTECODE_ID --json-argument '{"key": "value"}'
```

### query-application

Query application state.

```bash
linera query-application <APPLICATION_ID> <QUERY>

Example:
    linera query-application APP_ID '{"value": null}'
```

## Service Commands

### service

Start the node service with GraphQL API.

```bash
linera service [OPTIONS]

Options:
    --port <PORT>               Port to listen on [default: 8080]
    --address <ADDRESS>         Bind address [default: 127.0.0.1]
    --expose-graph-schema       Expose GraphQL schema
    --skip-tracked-messages     Skip processing tracked messages

Example:
    # Start service on port 8080
    linera service --port 8080
    
    # Access GraphiQL
    open http://localhost:8080
```

## Network Commands

### net up

Start a local test network.

```bash
linera net up [OPTIONS]

Options:
    --port <PORT>               Faucet port
    --with-faucet               Start with faucet
    --faucet-port <PORT>        Faucet port
    --validators <COUNT>        Number of validators
    --shards <COUNT>            Number of shards per validator

Example:
    linera net up --with-faucet --faucet-port 8080
```

### net helper

Print shell helper functions.

```bash
source /dev/stdin <<<"$(linera net helper 2>/dev/null)"
```

## Ownership Commands

### change-ownership

Change chain ownership.

```bash
linera change-ownership [OPTIONS] <CHAIN_ID>

Options:
    --owners <OWNERS>...        New owner public keys
    --remove-owners <OWNERS>... Owners to remove
    --multi-leader-rounds <N>   Multi-leader rounds

Example:
    linera change-ownership CHAIN_ID --owners NEW_OWNER1 NEW_OWNER2
```

### change-application-permissions

Change application permissions on chain.

```bash
linera change-application-permissions [OPTIONS] <CHAIN_ID>

Options:
    --close-chain <APP_ID>      App authorized to close chain
    --change-ownership <APP_ID> App authorized to change ownership
    --change-application-permissions <APP_ID>

Example:
    linera change-application-permissions CHAIN_ID \
        --close-chain APP_ID \
        --change-ownership APP_ID
```

## Key Management

### keygen

Generate new key pair.

```bash
linera keygen

Output:
    Public Key: 0x...
    Private Key: 0x... (store securely!)
```

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `LINERA_WALLET` | Wallet file path | `~/.linera/wallet.json` |
| `LINERA_KEYSTORE` | Keystore file path | `~/.linera/keystore.json` |
| `LINERA_STORAGE` | Storage configuration | `rocksdb:~/.linera/client.db` |
| `LINERA_APPLICATION_LOGS` | Enable app logs | `true` |

## Common Workflows

### Setup Development Environment

```bash
# 1. Build Linera
cargo build --release -p linera-service

# 2. Set PATH
export PATH="$PWD/target/release:$PATH"

# 3. Source helper
source /dev/stdin <<<"$(linera net helper 2>/dev/null)"

# 4. Start local network
linera_spawn linera net up --with-faucet --faucet-port 8080

# 5. Initialize wallet
export FAUCET_URL=http://localhost:8080
linera wallet init --faucet $FAUCET_URL

# 6. Request chains
INFO1=($(linera wallet request-chain --faucet $FAUCET_URL))
INFO2=($(linera wallet request-chain --faucet $FAUCET_URL))
CHAIN1="${INFO1[0]}"
CHAIN2="${INFO2[0]}"
```

### Deploy Application

```bash
# 1. Build contract and service
cargo build --release --target wasm32-unknown-unknown

# 2. Publish and create
APP_ID=$(linera publish-and-create \
    ./target/wasm32-unknown-unknown/release/contract.wasm \
    ./target/wasm32-unknown-unknown/release/service.wasm \
    --json-argument '{"initial_value": 0}' | grep "Application" | awk '{print $2}')

# 3. Start service
linera service --port 8080

# 4. Query application
curl http://localhost:8080/chains/$CHAIN1/applications/$APP_ID \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"query": "{ value }"}'
```

### Create Multi-Sig Wallet

```bash
# 1. Generate owner keys
OWNER1=$(linera keygen | grep "Public Key" | awk '{print $3}')
OWNER2=$(linera keygen | grep "Public Key" | awk '{print $3}')
OWNER3=$(linera keygen | grep "Public Key" | awk '{print $3}')

# 2. Create multi-owner chain
linera open-multi-owner-chain \
    --from $CHAIN1 \
    --owners $OWNER1 $OWNER2 $OWNER3 \
    --initial-balance 1000 \
    --multi-leader-rounds 2
```

## Troubleshooting

### Wallet Locked

```bash
# Wallet may be locked by another process
# Ensure no other linera processes are running
pkill -f linera
```

### Storage Errors

```bash
# Reset storage (WARNING: Destroys data!)
rm -rf ~/.linera/client.db
```

### Connection Refused

```bash
# Check if validator is running
linera net status

# Restart local network
linera net up --with-faucet
```

## See Also

- [GraphQL API](./graphql-api.md)
- [SDK API](./sdk-api.md)
- [Linera Documentation](https://linera.dev)
