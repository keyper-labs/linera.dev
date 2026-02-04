# Linera Architecture Diagrams

Visual reference for Linera blockchain architecture, data flows, and system components.

## Available Diagrams

| Diagram | Description | File |
|---------|-------------|------|
| **System Architecture** | High-level system overview | [system-architecture.md](./system-architecture.md) |
| **Microchain Lifecycle** | Chain creation and management | [microchain-lifecycle.md](./microchain-lifecycle.md) |
| **Message Flow** | Cross-chain messaging patterns | [message-flow.md](./message-flow.md) |
| **Application Architecture** | Application component structure | [application-architecture.md](./application-architecture.md) |
| **Multisig Flow** | Multisig proposal/approval/execution | [multisig-flow.md](./multisig-flow.md) |
| **Validator Architecture** | Validator node structure | [validator-architecture.md](./validator-architecture.md) |

---

## Quick Reference

### Linera Architecture Overview

```

                         Client Layer                             

  CLI Wallet   Web Client    dApp         Node Service        
  (linera)    (@linera/     (Browser)     (GraphQL)           
               client)                                        

                                                   
       
                             gRPC / RPC
                            

                      Validator Network                           
                   
    Validator      Validator      Validator    ...         
     Node 1         Node 2         Node N                  
                   

                            
                            

                      Microchain Layer                            
         
   Chain 1   Chain 2   Chain 3   Chain 4   Chain N    
  (Single)  (Multi)   (Public)  (App)     (...)       
         

```

### Chain Ownership Types

```
    
  Single-Owner       Multi-Owner        Public Chain   
     Chain              Chain                          
    
  Owner: A           Owners: A,B,C      Owners: None   
                     Threshold: 2                      
                             
    Fast                   Any        
    Rounds           Multi-           User       
          Leader           
                       Rounds                        
  Low latency              Open to all    
  Single writer                                        
                     Single-Leader      Shared apps    
  Best for:          Fallback                          
  - Personal                            Best for:      
  - High freq        Best for:          - Public       
                     - Team               services     
                     - Shared           - Shared       
                       control            state        
    
```

---

## Diagram Format

All diagrams are provided in:
- **Mermaid** format (for rendering in Markdown)
- **ASCII** diagrams (for terminal viewing)
- **SVG** references (for high-quality rendering)

---

## Contributing

When adding new diagrams:
1. Use Mermaid syntax for maintainability
2. Include ASCII fallback
3. Add to the index in this README
4. Document the diagram's purpose and key insights

---

## External Resources

- [Mermaid Live Editor](https://mermaid.live/)
- [Linera Whitepaper Diagrams](https://linera.io/whitepaper)
- [Architecture Decision Records](../sdk/linera-sdk-architecture-decision-records.md)
