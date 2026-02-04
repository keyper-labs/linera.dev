# Linera GraphQL API

GraphQL interface for querying application state through the Service component.

## Overview

The GraphQL API is exposed by the **Service** component of Linera applications. It provides read-only access to application state.

> **Important**: GraphQL is read-only. State modifications must be done through operations executed by the Contract.

## Status

| Aspect | Status | Notes |
|--------|--------|-------|
| Schema Introspection |  Limited | Testnet Conway schema loading issues reported |
| Query Execution |  Working | Basic queries functional |
| Subscriptions |  Not Available | Use polling instead |
| Mutations |  Not Available | Use operations via Contract |

## Starting the GraphQL Service

```bash
# Start node service with GraphQL
linera service --port 8080

# Access GraphiQL UI
open http://localhost:8080
```

## Endpoint Structure

```
http://localhost:8080/chains/{CHAIN_ID}/applications/{APP_ID}
```

## Query Structure

### Basic Query

```graphql
query {
  applicationState {
    value
  }
}
```

### With Parameters

```graphql
query GetBalance($owner: AccountOwner!) {
  balance(owner: $owner) {
    amount
    token
  }
}
```

Variables:
```json
{
  "owner": "0x1234..."
}
```

## Example: Counter Application

### Query State

```graphql
query {
  value
}
```

Response:
```json
{
  "data": {
    "value": 42
  }
}
```

### Query with Nested Fields

```graphql
query {
  application {
    id
    state {
      value
      lastModified
    }
    owner
  }
}
```

## Example: Fungible Token

### Query Balance

```graphql
query GetBalance($account: Account!) {
  balance(account: $account)
}
```

### Query Total Supply

```graphql
query {
  totalSupply
}
```

### Query All Balances

```graphql
query {
  accounts {
    account
    balance
  }
}
```

## Example: Multisig Application

### Query Proposal

```graphql
query GetProposal($proposalId: ID!) {
  proposal(id: $proposalId) {
    id
    proposer
    status
    threshold
    approvals
    operations {
      type
      payload
    }
    createdAt
    expiresAt
  }
}
```

### Query Wallet State

```graphql
query {
  wallet {
    owners
    threshold
    proposalCount
    pendingProposals {
      id
      status
    }
  }
}
```

## Error Handling

### Common Errors

```json
{
  "errors": [
    {
      "message": "Unknown field 'chainId'",
      "locations": [{"line": 2, "column": 3}]
    }
  ]
}
```

### Error Codes

| Error | Meaning | Solution |
|-------|---------|----------|
| `Unknown field` | Field doesn't exist in schema | Check field name |
| `Invalid argument` | Wrong argument type | Verify argument format |
| `Application not found` | Invalid app ID | Check application ID |
| `Chain not found` | Invalid chain ID | Verify chain exists |

## Integration Examples

### JavaScript/Fetch

```javascript
const response = await fetch(
  `http://localhost:8080/chains/${chainId}/applications/${appId}`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query: `
        query GetValue {
          value
        }
      `
    })
  }
);

const data = await response.json();
```

### TypeScript with Apollo Client

```typescript
import { ApolloClient, InMemoryCache, gql } from '@apollo/client';

const client = new ApolloClient({
  uri: `http://localhost:8080/chains/${chainId}/applications/${appId}`,
  cache: new InMemoryCache()
});

const GET_VALUE = gql`
  query GetValue {
    value
  }
`;

const result = await client.query({ query: GET_VALUE });
```

### cURL

```bash
curl -X POST http://localhost:8080/chains/CHAIN_ID/applications/APP_ID \
  -H "Content-Type: application/json" \
  -d '{"query": "{ value }"}'
```

## Limitations

### Current Limitations

1. **Read-Only**: Cannot modify state through GraphQL
2. **No Subscriptions**: Real-time updates not supported
3. **Schema Issues**: Introspection may not work on Testnet Conway
4. **Polling Required**: Use 5-10s polling for updates

### Workarounds

```typescript
// Polling pattern
const pollQuery = async (query, interval = 5000) => {
  while (true) {
    const result = await fetchGraphQL(query);
    updateUI(result);
    await sleep(interval);
  }
};
```

## Best Practices

1. **Query Only What You Need**
   ```graphql
   # Good
   query { value }
   
   # Avoid over-fetching
   query { value timestamp metadata ... }
   ```

2. **Handle Errors Gracefully**
   ```typescript
   const result = await query().catch(err => {
     console.error('GraphQL Error:', err);
     return fallbackData;
   });
   ```

3. **Use Variables for Dynamic Values**
   ```graphql
   query GetUser($id: ID!) {
     user(id: $id) { name }
   }
   ```

4. **Implement Polling for Real-Time Data**
   ```typescript
   useEffect(() => {
     const interval = setInterval(fetchData, 5000);
     return () => clearInterval(interval);
   }, []);
   ```

## Related Documentation

- [Service Runtime](./sdk-api.md#service-runtime)
- [TypeScript SDK](./typescript-sdk.md)
- [CLI Reference](./cli-reference.md#service-command)
