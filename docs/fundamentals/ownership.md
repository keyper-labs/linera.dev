# Chain Ownership

Chain ownership semantics, consensus modes, and access control.

## Ownership Models

Linera supports three chain ownership models:

```

                      OWNERSHIP MODELS                               

                                                                      
  SINGLE-OWNER CHAIN                    MULTI-OWNER CHAIN            
                               
     Owner: A                           Owners: A,B,C            
                                        Threshold: 2             
                                                    
     Authority                                    
     to propose                        Any owner             
     blocks                            can propose            
                                       
                                                                 
    Use case:                           Use case:                
    Personal chain                      Team treasury            
    High-frequency                      Shared control           
    applications                        Governance               
                               
                                                                      
                              PUBLIC CHAIN                           
                                                   
                                Owners: None                        
                                                                    
                                                       
                                 Open to                          
                                 all users                        
                                                       
                                                                    
                                Use case:                           
                                Shared apps                         
                                Public goods                        
                                                   
                                                                      

```

## Consensus Modes

### Single-Owner Chains: Fast Rounds

```

                     FAST ROUNDS                                     

                                                                      
   Owner                    Validator Network                        
                                               
                                                                      
                                                                   
       1. Create operation                                         
                                      
                                                                   
       2. Sign block proposal                                      
                                      
                                                                   
                                     3. Validate & execute         
                                        (no voting needed)         
                                                                   
       4. Confirmation                                             
                                      
                                                                   
                                                                      
   Properties:                                                        
   • Minimal latency (fastest possible)                              
   • No contention (only one proposer)                               
   • Best for: personal chains, high-frequency ops                   
                                                                      

```

### Multi-Owner Chains: Multi-Leader Rounds

```

                  MULTI-LEADER ROUNDS                                

                                                                      
   Owner A     Owner B     Owner C         Validators               
                                      
                                                                 
        Propose                                                  
                                                        
                  Propose                                        
                                                        
                                                                 
                                                   
                                    Contention!                 
                                                   
                                                                 
                                                   
                                    Select one                  
                                    (round-robin                
                                     + timeout)                 
                                                   
                                                                 
        Winner confirmed      
                                                                 
                                                                      
   Properties:                                                        
   • Multiple owners can propose                                     
   • Validators coordinate to select one                             
   • Fallback to single-leader if too much contention                
   • Best for: shared control, occasional conflicts                  
                                                                      

```

### Multi-Owner Chains: Single-Leader Rounds

```

                  SINGLE-LEADER ROUNDS                               

                                                                      
   Time-based rotation for high-contention scenarios:                
                                                                      
   t=0       t=1       t=2       t=3       t=4                       
                                           
    A  B  C  A  B  ...                    
                                           
  Leader    Leader   Leader   Leader   Leader                        
                                                                      
   Properties:                                                        
   • Predictable leader schedule                                     
   • Eliminates contention completely                                
   • Trade-off: higher latency (wait for slot)                       
   • Best for: high-activity shared chains                           
                                                                      

```

## Owner Management

### Creating Multi-Owner Chains

```bash
# Create a multi-owner chain with owners A, B, C
linera open-multi-owner-chain \
  --from "$CHAIN" \
  --owners "$OWNER_A" "$OWNER_B" "$OWNER_C"
```

### Changing Ownership

```

                    OWNERSHIP CHANGES                                

                                                                      
  ADD OWNER:                                                          
                                                           
   Current   Owners: [A, B]                                         
    State                                                           
                                                           
         Operation: AddOwner(C)                                     
         (signed by existing owner)                                 
                                                                     
                                                           
    New      Owners: [A, B, C]                                      
    State                                                           
                                                           
                                                                      
  REMOVE OWNER:                                                       
                                                           
   Current   Owners: [A, B, C]                                      
    State                                                           
                                                           
         Operation: RemoveOwner(B)                                  
         (signed by existing owner)                                 
                                                                     
                                                           
    New      Owners: [A, C]                                         
    State                                                           
                                                           
                                                                      
  TRANSFER OWNERSHIP:                                                 
                                                           
   Current   Owner: [A]                                              
    State                                                           
                                                           
         Operation: ChangeOwners([B])                               
                                                                     
                                                           
    New      Owner: [B]                                              
    State                                                           
                                                           
                                                                      

```

## Access Control

### Permission Levels

| Action | Single-Owner | Multi-Owner | Public |
|--------|--------------|-------------|--------|
| **Propose block** | Owner only | Any owner | Any user |
| **Change owners** | Owner only | Owner consensus | N/A |
| **Close chain** | Owner only | Owner consensus | Admin only |
| **Receive messages** | Automatic | Automatic | Automatic |

### Application-Level Permissions

Applications can implement additional access control:

```rust
// Example: Restrict operation to owners
fn execute_operation(context: &OperationContext, operation: Operation) {
    // Verify caller is a chain owner
    assert!(context.authenticated_signer.is_some());
    
    // Additional application-specific checks
    match operation {
        Operation::AdminAction { .. } => {
            assert!(is_admin(context.authenticated_signer.unwrap()));
        }
        Operation::UserAction { .. } => {
            // Any owner can execute
        }
    }
}
```

---

## Related Documentation

- [Microchains](./microchains.md)
- [Applications](./applications.md)
- [Multisig Flow](../diagrams/multisig-flow.md)
