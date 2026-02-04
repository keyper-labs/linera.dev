# Message Flow

Cross-chain messaging patterns and data flow.

## Message Types

```mermaid
flowchart TB
    subgraph Types["Message Categories"]
        direction TB
        
        subgraph System["System Messages"]
            SM1["Chain Creation"]
            SM2["Chain Closing"]
            SM3["Owner Changes"]
        end
        
        subgraph User["User Messages"]
            UM1["Simple Transfer"]
            UM2["Application Message"]
            UM3["Cross-Chain Call"]
        end
        
        subgraph App["Application Messages"]
            AM1["Token Transfer"]
            AM2["NFT Bridge"]
            AM3["Data Sync"]
        end
    end
    
    subgraph Properties["Message Properties"]
        P1["Tracked: Delivery confirmed"]
        P2["Bouncing: Error handling"]
        P3["Skipping: Optional delivery"]
    end
    
    System --> Properties
    User --> Properties
    App --> Properties
```

## Cross-Chain Transfer Flow

```

                      CROSS-CHAIN TRANSFER FLOW                            

                                                                           
  Step 1: Initiate on Source Chain                                         
                                                            
     User                                                                
    Operation                                                            
                                                            
                                                                          
                                                                          
                                                            
     Source      1. Deduct balance from user                             
     Chain       2. Create outgoing message                                
     (Local)     3. Add to outbox                                         
                                                            
                                                                          
           Message: {                                                       
             origin: SourceChain,                                           
             destination: TargetChain,                                      
             authenticated_signer: User,                                    
             amount: 100,                                                   
             kind: Tracked                                                  
           }                                                                
                                                                          
                                                                          
       
                        VALIDATOR NETWORK                                
                           
        V1         V2         V3         V4                    
                           
                              
                                                                       
       
                                                                          
                                                                          
  Step 2: Routing and Delivery                                             
       
    Validators:                                                         
    • Track outgoing messages from each chain                           
    • Queue messages in target chain's inbox                            
    • Provide proofs of delivery                                        
       
                                                                          
                                                                          
  Step 3: Receive on Target Chain                                          
                                                            
     Target      1. Message appears in inbox                            
     Chain       2. Owner includes message in next block                
     Inbox       3. Process message (credit recipient)                  
                                                            
                                                                           
       
    Result:                                                             
    • User balance: -100 on Source                                      
    • Recipient balance: +100 on Target                                 
    • Both changes validated by same validator set                      
       
                                                                           

```

## Inbox/Outbox Model

```mermaid
flowchart LR
    subgraph Source["Source Chain"]
        direction TB
        Block1["Block N"]
        Outbox["Outbox Queue"]
        Block2["Block N+1"]
    end
    
    subgraph Network["Validator Network"]
        V1["V1"]
        V2["V2"]
        V3["V3"]
    end
    
    subgraph Target["Target Chain"]
        direction TB
        Inbox["Inbox Queue"]
        Block3["Block M"]
        Block4["Block M+1"]
    end
    
    Block1 -->|emit message| Outbox
    Outbox -->|broadcast| V1
    Outbox -->|broadcast| V2
    Outbox -->|broadcast| V3
    V1 -->|deliver| Inbox
    V2 -->|deliver| Inbox
    V3 -->|deliver| Inbox
    Inbox -->|process| Block3
    Block3 -->|continue| Block4
```

```

                     INBOX / OUTBOX MODEL                             

                                                                      
   SOURCE CHAIN                    TARGET CHAIN                       
                                               
                                                                      
                                        
      Block                         Block                         
      Being                         Being                         
      Created                       Created                       
                                        
                                                                    
            Execute operation              Select messages          
                           from inbox               
                                                                    
            Side effect:                                            
            Add to OUTBOX                                           
                                                                    
                                        
                                                                  
      OUTBOX                        INBOX                         
                                                                  
    [Msg to A]           [Msg from X]                    
    [Msg to B]            [Msg from Y]                    
    [Msg to C]              [Msg from Z]                    
                                                               
                                     
                                                                  
                          VALIDATORS (shared security)            
                                           
                                             
                                              
                                                                      
   Key properties:                                                    
   • Outbox is ordered (FIFO)                                         
   • Inbox messages must be processed in order                        
   • Owner chooses which messages to include                          
   • Messages can skip if application allows                          
                                                                      

```

## Message Kinds

```

                         MESSAGE KINDS                                   

                                                                         
  TRACKED MESSAGES (Guaranteed delivery)                                 
                                                          
     Send                                                              
     Message                                                           
                                                          
                                                                        
                                                                        
                           
    Message      In Target    Process                   
    in Outbox         Inbox             Success                   
                           
                                                                       
                               If process fails                       
                                                                       
                                                         
                       Bounce                                         
                       Back                                           
                                                         
                                                                       
           Returns to source chain                  
                                                                         
     
                                                                         
  BOUNCING MESSAGES (Error handling)                                     
                                                          
     Send        Same flow as tracked, but:                            
     (Bounce)    • Error response handled specially                    
    • Application can react to failure                    
                                                                        
                                                                        
                           
    Process       Error       Bounce                    
    Attempt            Occurs           Response                  
                           
                                                                        
                                                                        
                                                        
                                           Source                    
                                           Handles                   
                                           Error                     
                                                        
                                                                         
     
                                                                         
  SKIPPING MESSAGES (Optional delivery)                                  
                                                          
     Send        • Target chain can skip without bouncing              
     (Skip)      • Use case: notifications, non-critical updates       
    • Sender doesn't require confirmation                 
                                                                        
                                                                        
                           
    Message      Target       Process OR                
    Sent              Receives          Skip                      
                           
                                                                        
                                                                        
                                                          
                                                       Dropped         
                                                      (No bounce)      
                                                          
                                                                         

```

## Authentication Chain

```

                    AUTHENTICATION PROPAGATION                       

                                                                     
  Cross-chain messages maintain authentication context               
                                                                     
  Chain A  Chain B  Chain C                
                                                                     
                                   
    User               App               App                  
    Signs             on B              on C                  
                                   
                                                                  
        Operation          Message            Message             
                                                                  
   
    authenticated_signer: User (original signer)                  
    authenticated_caller: Chain A → Chain B → Chain C             
                                                                  
    Application can:                                              
    • Verify original signer                                      
    • Verify calling chain path                                   
    • Implement replay protection                                 
   
                                                                     
  Example: User on A calls cross-chain swap                          
  1. User signs operation on Chain A                                 
  2. Chain A sends message to DEX on Chain B                         
  3. DEX on B sends message to Token on Chain C                      
  4. Token on C sees: signer=User, path=A→B→C                       
  5. Token verifies User's balance on A (via state proof)           
                                                                     

```

## Message Latency

| Path | Expected Latency | Notes |
|------|------------------|-------|
| Same chain | 1 block | Immediate execution |
| Cross-chain (same validator set) | 2-3 blocks | One block each + routing |
| Cross-chain (with finality) | 6+ blocks | Additional confirmation depth |

---

## Related Documentation

- [System Architecture](./system-architecture.md)
- [Microchain Lifecycle](./microchain-lifecycle.md)
- [Multisig Flow](./multisig-flow.md)
