# @linera/client TypeScript SDK

Frontend SDK for browser-based Linera applications.

## Installation

```bash
npm install @linera/client
# or
yarn add @linera/client
# or
pnpm add @linera/client
```

## Overview

| Feature | Status | Notes |
|---------|--------|-------|
| Wallet Management |  Available | Key generation, storage |
| Chain Queries |  Available | Balance, state |
| Operations |  Available | Submit transactions |
| Multi-Owner Chains |  Available | Create and manage |
| Cross-Chain Messages |  Available | Send/receive |
| Backend Usage |  Not Supported | Frontend only |

> **Important**: @linera/client is a **frontend-only** SDK. It cannot be used in Node.js backend applications.

## Quick Start

```typescript
import * as linera from '@linera/client';

// Initialize client
const client = await linera.createClient({
  network: 'testnet-conway'
});

// Create or load wallet
const wallet = await client.createWallet();

// Get balance
const balance = await client.queryBalance(chainId);

// Transfer tokens
const certificate = await client.transfer({
  from: chainId,
  to: recipientChain,
  amount: 100n,
});
```

## Wallet Management

### Create New Wallet

```typescript
import { createClient } from '@linera/client';

const client = await createClient({ network: 'testnet-conway' });

// Create new wallet with random keys
const wallet = await client.createWallet();

// Access wallet info
console.log(wallet.publicKey);
console.log(wallet.address);
```

### Import Wallet

```typescript
// From seed phrase
const wallet = await client.importWalletFromSeed(seedPhrase);

// From private key
const wallet = await client.importWalletFromPrivateKey(privateKey);
```

### Export Wallet

```typescript
// Export seed phrase
const seedPhrase = await wallet.exportSeedPhrase();

// Export private key
const privateKey = await wallet.exportPrivateKey();
```

### Secure Storage

```typescript
// Store encrypted wallet
const encrypted = await wallet.encrypt(password);
localStorage.setItem('wallet', encrypted);

// Load and decrypt
const encrypted = localStorage.getItem('wallet');
const wallet = await client.loadWallet(encrypted, password);
```

## Chain Operations

### Request Chain from Faucet

```typescript
const { chainId, account } = await client.requestChain({
  faucetUrl: 'https://faucet.testnet-conway.linera.net'
});
```

### Create Multi-Owner Chain

```typescript
const multiOwnerChain = await client.createMultiOwnerChain({
  from: sourceChainId,
  owners: [owner1, owner2, owner3],
  threshold: 2, // Number of multi-leader rounds
  initialBalance: 1000n
});
```

### Query Chain Balance

```typescript
// Query chain balance
const balance = await client.queryBalance(chainId);

// Query account balance on chain
const balance = await client.queryBalance(`${account}@${chainId}`);
```

### Transfer Tokens

```typescript
// Transfer between chains
const certificate = await client.transfer({
  from: chain1,
  to: chain2,
  amount: 100n
});

// Transfer to account
const certificate = await client.transfer({
  from: chain1,
  to: `${account}@${chain2}`,
  amount: 50n
});
```

## Application Operations

### Publish and Create Application

```typescript
// Read WASM files
const contractWasm = await fetch('/contract.wasm').then(r => r.bytes());
const serviceWasm = await fetch('/service.wasm').then(r => r.bytes());

// Publish bytecode and create instance
const appId = await client.publishAndCreate({
  chainId,
  contract: contractWasm,
  service: serviceWasm,
  initArgs: { initialValue: 0 }
});
```

### Execute Operation

```typescript
const certificate = await client.executeOperation({
  chainId,
  applicationId,
  operation: {
    increment: {}
  }
});
```

### Query Application

```typescript
const state = await client.queryApplication({
  chainId,
  applicationId,
  query: { value: null }
});
```

## Multi-Owner Chain Management

### Create Multi-Owner Chain

```typescript
const { chainId } = await client.createMultiOwnerChain({
  from: sourceChainId,
  owners: [
    '0x1234...', // Owner 1 public key
    '0x5678...', // Owner 2 public key
    '0x9abc...', // Owner 3 public key
  ],
  multiLeaderRounds: 2,
  initialBalance: 1000n
});
```

### Change Ownership

```typescript
await client.changeOwnership({
  chainId,
  newOwners: [owner1, owner2, owner4], // Replace owner3 with owner4
  multiLeaderRounds: 2
});
```

## Cross-Chain Messaging

### Send Message

```typescript
const certificate = await client.sendMessage({
  from: sourceChainId,
  to: destinationChainId,
  applicationId,
  message: {
    credit: {
      owner: recipient,
      amount: 100n
    }
  },
  authenticate: true // Forward signer authentication
});
```

### Process Inbox

```typescript
// Process pending messages
const messages = await client.processInbox(chainId);
```

## Event Handling

### Poll for Updates

```typescript
// Polling-based updates (recommended)
const pollBalance = async (chainId: string, interval = 5000) => {
  while (true) {
    const balance = await client.queryBalance(chainId);
    updateUI(balance);
    await sleep(interval);
  }
};

// Start polling
pollBalance(chainId);
```

### Certificate Notifications

```typescript
client.onCertificate((certificate) => {
  console.log('New certificate:', certificate.hash);
  console.log('Chain:', certificate.chainId);
  console.log('Height:', certificate.height);
});
```

## React Integration

### Provider Setup

```typescript
// LineraProvider.tsx
import { createClient, LineraClient } from '@linera/client';
import { createContext, useContext, useEffect, useState } from 'react';

const LineraContext = createContext<LineraClient | null>(null);

export function LineraProvider({ children }) {
  const [client, setClient] = useState<LineraClient | null>(null);

  useEffect(() => {
    createClient({ network: 'testnet-conway' })
      .then(setClient);
  }, []);

  if (!client) return <div>Loading...</div>;

  return (
    <LineraContext.Provider value={client}>
      {children}
    </LineraContext.Provider>
  );
}

export function useLinera() {
  return useContext(LineraContext);
}
```

### Hook Example

```typescript
// useBalance.ts
import { useEffect, useState } from 'react';
import { useLinera } from './LineraProvider';

export function useBalance(chainId: string) {
  const client = useLinera();
  const [balance, setBalance] = useState<bigint | null>(null);

  useEffect(() => {
    if (!client || !chainId) return;

    const fetchBalance = async () => {
      const bal = await client.queryBalance(chainId);
      setBalance(bal);
    };

    fetchBalance();
    const interval = setInterval(fetchBalance, 5000);
    return () => clearInterval(interval);
  }, [client, chainId]);

  return balance;
}
```

### Component Example

```typescript
// WalletComponent.tsx
import { useState } from 'react';
import { useLinera } from './LineraProvider';
import { useBalance } from './useBalance';

export function WalletComponent({ chainId }: { chainId: string }) {
  const client = useLinera();
  const balance = useBalance(chainId);
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');

  const handleTransfer = async () => {
    await client.transfer({
      from: chainId,
      to: recipient,
      amount: BigInt(amount)
    });
  };

  return (
    <div>
      <p>Balance: {balance?.toString()}</p>
      <input
        placeholder="Recipient"
        value={recipient}
        onChange={e => setRecipient(e.target.value)}
      />
      <input
        placeholder="Amount"
        value={amount}
        onChange={e => setAmount(e.target.value)}
      />
      <button onClick={handleTransfer}>Transfer</button>
    </div>
  );
}
```

## Error Handling

```typescript
try {
  const certificate = await client.transfer({...});
} catch (error) {
  if (error instanceof LineraError) {
    switch (error.code) {
      case 'INSUFFICIENT_BALANCE':
        alert('Not enough funds');
        break;
      case 'INVALID_SIGNATURE':
        alert('Signature verification failed');
        break;
      case 'CHAIN_NOT_FOUND':
        alert('Chain does not exist');
        break;
      default:
        console.error('Linera error:', error);
    }
  }
}
```

## Configuration

### Network Options

```typescript
const client = await createClient({
  // Predefined network
  network: 'testnet-conway',
  
  // Or custom network
  network: {
    name: 'custom',
    faucetUrl: 'https://faucet.example.com',
    validator: 'validator.example.com:443'
  },
  
  // Optional: custom storage
  storage: {
    getItem: (key) => localStorage.getItem(key),
    setItem: (key, value) => localStorage.setItem(key, value)
  }
});
```

### Types

```typescript
import type {
  ChainId,
  ApplicationId,
  AccountOwner,
  Amount,
  Certificate,
  Operation,
  Message,
  Wallet
} from '@linera/client';
```

## Browser Compatibility

| Browser | Status | Notes |
|---------|--------|-------|
| Chrome 90+ |  Supported | Full support |
| Firefox 88+ |  Supported | Full support |
| Safari 14+ |  Supported | Full support |
| Edge 90+ |  Supported | Full support |

## Limitations

1. **Frontend Only**: Cannot be used in Node.js backend
2. **No WebSocket**: Use polling for real-time updates
3. **Browser Storage**: Keys stored in browser localStorage (encrypt sensitive wallets)
4. **Wasm Compilation**: Requires WASM support in browser

## Security Best Practices

```typescript
// 1. Always encrypt wallets
const encrypted = await wallet.encrypt(strongPassword);

// 2. Clear sensitive data
wallet.clear(); // Remove from memory

// 3. Use secure storage
const secureStorage = {
  getItem: async (key) => {
    // Use encrypted storage
  },
  setItem: async (key, value) => {
    // Encrypt before storing
  }
};
```

## See Also

- [@linera/client npm](https://www.npmjs.com/package/@linera/client)
- [Linera Documentation](https://linera.dev)
- [Example Applications](https://github.com/linera-io/linera-web/)
