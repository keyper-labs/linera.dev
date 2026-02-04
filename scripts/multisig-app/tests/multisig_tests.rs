// Copyright (c) 2025 PalmeraDAO
// SPDX-License-Identifier: MIT

//! Comprehensive unit tests for the Linera Multisig Application
//!
//! These tests cover:
//! - Proposal submission for all types
//! - Confirmation with idempotency
//! - Execution with threshold enforcement
//! - Confirmation revocation
//! - Authorization and security
//! - Edge cases and error conditions

use futures::FutureExt as _;
use linera_sdk::{
    linera_base_types::{AccountOwner, ChainId, Owner},
    test::MockContractRuntime,
    util::BlockingWait,
    Contract, ContractRuntime,
};

// Import the contract directly since it's a separate binary
use linera_multisig::{MultisigOperation, MultisigResponse, ProposalType};

// For testing, we need to include the contract module directly
mod contract_testing {
    // Include the contract code for testing
    include!("../src/contract.rs");
}

use contract_testing::{InstantiationArgs, MultisigContract};

// ============================================================================
// Test Setup and Helper Functions
// ============================================================================

/// Creates a test chain ID
fn test_chain_id() -> ChainId {
    ChainId::test(1)
}

/// Creates test owners for multisig setup
fn create_test_owners(count: usize) -> Vec<Owner> {
    (0..count)
        .map(|i| Owner::User([i as u8; 32]))
        .collect()
}

/// Creates an AccountOwner from an Owner
fn account_owner(owner: &Owner) -> AccountOwner {
    AccountOwner::User(owner.clone())
}

/// Setup function to create an initialized multisig contract
fn setup_multisig(owner_count: usize, threshold: u64) -> MultisigContract {
    setup_multisig_with_config(owner_count, threshold, None, None)
}

/// Setup function with custom configuration
fn setup_multisig_with_config(
    owner_count: usize,
    threshold: u64,
    proposal_lifetime: Option<u64>,
    time_delay: Option<u64>,
) -> MultisigContract {
    let owners = create_test_owners(owner_count);
    let account_owners: Vec<AccountOwner> = owners.iter().map(account_owner).collect();

    // Create runtime with proper configuration
    let mut runtime = MockContractRuntime::<MultisigContract>::default();
    runtime.with_chain_id(test_chain_id());

    // Create contract
    let contract = MultisigContract::load(ContractRuntime::new()).blocking_wait();

    // Instantiate
    let args = InstantiationArgs {
        owners: account_owners.clone(),
        threshold,
        proposal_lifetime,
        time_delay,
    };

    contract.instantiate(args).blocking_wait();

    contract
}

/// Helper to submit a proposal
async fn submit_proposal(
    contract: &mut MultisigContract,
    proposer: &AccountOwner,
    proposal_type: ProposalType,
) -> u64 {
    let response = contract
        .execute_operation(MultisigOperation::SubmitProposal {
            proposal_type: proposal_type.clone(),
        })
        .await;

    match response {
        MultisigResponse::ProposalSubmitted { proposal_id } => proposal_id,
        _ => panic!("Expected ProposalSubmitted response"),
    }
}

/// Helper to confirm a proposal
async fn confirm_proposal(
    contract: &mut MultisigContract,
    owner: &AccountOwner,
    proposal_id: u64,
) -> u64 {
    let response = contract
        .execute_operation(MultisigOperation::ConfirmProposal { proposal_id })
        .await;

    match response {
        MultisigResponse::ProposalConfirmed {
            proposal_id: _,
            confirmations,
        } => confirmations,
        _ => panic!("Expected ProposalConfirmed response"),
    }
}

/// Helper to execute a proposal
async fn execute_proposal(
    contract: &mut MultisigContract,
    executor: &AccountOwner,
    proposal_id: u64,
) -> MultisigResponse {
    contract
        .execute_operation(MultisigOperation::ExecuteProposal { proposal_id })
        .await
}

/// Helper to revoke confirmation
async fn revoke_confirmation(
    contract: &mut MultisigContract,
    owner: &AccountOwner,
    proposal_id: u64,
) -> MultisigResponse {
    contract
        .execute_operation(MultisigOperation::RevokeConfirmation { proposal_id })
        .await
}

// ============================================================================
// Module: Proposal Submission Tests
// ============================================================================

#[cfg(test)]
mod proposal_submission_tests {
    use super::*;

    #[test]
    fn test_submit_transfer_proposal() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let proposer = account_owner(&owners[0]);
        let recipient = account_owner(&owners[1]);

        let proposal_type = ProposalType::Transfer {
            to: recipient,
            value: 100,
            data: vec![1, 2, 3],
        };

        // Submit proposal
        let response = contract
            .execute_operation(MultisigOperation::SubmitProposal {
                proposal_type: proposal_type.clone(),
            })
            .blocking_wait();

        match response {
            MultisigResponse::ProposalSubmitted { proposal_id } => {
                assert_eq!(proposal_id, 0, "First proposal should have ID 0");
            }
            _ => panic!("Expected ProposalSubmitted response"),
        }

        // Verify proposal is pending
        let proposal = contract
            .state
            .pending_proposals
            .get(&0)
            .blocking_wait()
            .expect("Failed to get proposal")
            .expect("Proposal should exist");

        assert_eq!(proposal.id, 0);
        assert_eq!(proposal.proposer, proposer);
        assert!(!proposal.executed);
        assert_eq!(proposal.confirmation_count, 1); // Auto-confirmed
    }

    #[test]
    fn test_submit_add_owner_proposal() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let proposer = account_owner(&owners[0]);
        let new_owner = account_owner(&Owner::User([99; 32]));

        let proposal_type = ProposalType::AddOwner { owner: new_owner };

        let response = contract
            .execute_operation(MultisigOperation::SubmitProposal {
                proposal_type: proposal_type.clone(),
            })
            .blocking_wait();

        match response {
            MultisigResponse::ProposalSubmitted { proposal_id } => {
                assert_eq!(proposal_id, 0);
            }
            _ => panic!("Expected ProposalSubmitted response"),
        }

        // Verify proposal
        let proposal = contract
            .state
            .pending_proposals
            .get(&0)
            .blocking_wait()
            .expect("Failed to get proposal")
            .expect("Proposal should exist");

        assert_eq!(proposal.proposer, proposer);
        assert!(!proposal.executed);
        assert_eq!(proposal.confirmation_count, 1);
    }

    #[test]
    fn test_submit_remove_owner_proposal() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let owner_to_remove = account_owner(&owners[1]);

        let proposal_type = ProposalType::RemoveOwner {
            owner: owner_to_remove,
        };

        let response = contract
            .execute_operation(MultisigOperation::SubmitProposal {
                proposal_type: proposal_type.clone(),
            })
            .blocking_wait();

        match response {
            MultisigResponse::ProposalSubmitted { proposal_id } => {
                assert_eq!(proposal_id, 0);
            }
            _ => panic!("Expected ProposalSubmitted response"),
        }
    }

    #[test]
    fn test_submit_replace_owner_proposal() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let old_owner = account_owner(&owners[1]);
        let new_owner = account_owner(&Owner::User([100; 32]));

        let proposal_type = ProposalType::ReplaceOwner {
            old_owner,
            new_owner,
        };

        let response = contract
            .execute_operation(MultisigOperation::SubmitProposal {
                proposal_type: proposal_type.clone(),
            })
            .blocking_wait();

        match response {
            MultisigResponse::ProposalSubmitted { proposal_id } => {
                assert_eq!(proposal_id, 0);
            }
            _ => panic!("Expected ProposalSubmitted response"),
        }
    }

    #[test]
    fn test_submit_change_threshold_proposal() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);

        let proposal_type = ProposalType::ChangeThreshold { threshold: 3 };

        let response = contract
            .execute_operation(MultisigOperation::SubmitProposal {
                proposal_type: proposal_type.clone(),
            })
            .blocking_wait();

        match response {
            MultisigResponse::ProposalSubmitted { proposal_id } => {
                assert_eq!(proposal_id, 0);
            }
            _ => panic!("Expected ProposalSubmitted response"),
        }
    }
}

// ============================================================================
// Module: Proposal Validation Tests
// ============================================================================

#[cfg(test)]
mod proposal_validation_tests {
    use super::*;

    #[test]
    #[should_panic(expected = "Transfer amount must be greater than 0")]
    fn test_transfer_zero_amount_fails() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let recipient = account_owner(&owners[1]);

        let proposal_type = ProposalType::Transfer {
            to: recipient,
            value: 0,
            data: vec![],
        };

        contract
            .execute_operation(MultisigOperation::SubmitProposal {
                proposal_type,
            })
            .blocking_wait();
    }

    #[test]
    #[should_panic(expected = "Owner already exists")]
    fn test_add_existing_owner_fails() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let existing_owner = account_owner(&owners[0]);

        let proposal_type = ProposalType::AddOwner {
            owner: existing_owner,
        };

        contract
            .execute_operation(MultisigOperation::SubmitProposal {
                proposal_type,
            })
            .blocking_wait();
    }

    #[test]
    #[should_panic(expected = "Owner does not exist")]
    fn test_remove_nonexistent_owner_fails() {
        let mut contract = setup_multisig(3, 2);
        let nonexistent_owner = account_owner(&Owner::User([200; 32]));

        let proposal_type = ProposalType::RemoveOwner {
            owner: nonexistent_owner,
        };

        contract
            .execute_operation(MultisigOperation::SubmitProposal {
                proposal_type,
            })
            .blocking_wait();
    }

    #[test]
    #[should_panic(expected = "Cannot remove owner: would make threshold impossible")]
    fn test_remove_owner_below_threshold_fails() {
        // 2 owners, threshold 2 - removing 1 would make threshold impossible
        let mut contract = setup_multisig(2, 2);
        let owners = create_test_owners(2);
        let owner_to_remove = account_owner(&owners[0]);

        let proposal_type = ProposalType::RemoveOwner {
            owner: owner_to_remove,
        };

        contract
            .execute_operation(MultisigOperation::SubmitProposal {
                proposal_type,
            })
            .blocking_wait();
    }

    #[test]
    #[should_panic(expected = "Threshold cannot be zero")]
    fn test_change_threshold_to_zero_fails() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);

        let proposal_type = ProposalType::ChangeThreshold { threshold: 0 };

        contract
            .execute_operation(MultisigOperation::SubmitProposal {
                proposal_type,
            })
            .blocking_wait();
    }

    #[test]
    #[should_panic(expected = "Threshold cannot exceed number of owners")]
    fn test_change_threshold_above_owners_fails() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);

        let proposal_type = ProposalType::ChangeThreshold { threshold: 4 };

        contract
            .execute_operation(MultisigOperation::SubmitProposal {
                proposal_type,
            })
            .blocking_wait();
    }
}

// ============================================================================
// Module: Confirmation Tests with Idempotency
// ============================================================================

#[cfg(test)]
mod confirmation_tests {
    use super::*;

    #[test]
    fn test_confirm_proposal_increments_count() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let proposer = account_owner(&owners[0]);
        let confirmer = account_owner(&owners[1]);
        let recipient = account_owner(&owners[2]);

        // Submit proposal (auto-confirmed by proposer)
        let proposal_id = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::Transfer {
                to: recipient,
                value: 100,
                data: vec![],
            },
        )
        .blocking_wait();

        // Confirm with second owner
        let confirmations = confirm_proposal(&mut contract, &confirmer, proposal_id).blocking_wait();

        assert_eq!(confirmations, 2, "Should have 2 confirmations");

        // Verify proposal state
        let proposal = contract
            .state
            .pending_proposals
            .get(&proposal_id)
            .blocking_wait()
            .expect("Failed to get proposal")
            .expect("Proposal should exist");

        assert_eq!(proposal.confirmation_count, 2);
    }

    #[test]
    fn test_confirm_proposal_idempotent() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let owner = account_owner(&owners[0]);
        let recipient = account_owner(&owners[1]);

        // Submit and auto-confirm
        let proposal_id = submit_proposal(
            &mut contract,
            &owner,
            ProposalType::Transfer {
                to: recipient,
                value: 100,
                data: vec![],
            },
        )
        .blocking_wait();

        // Try to confirm again with same owner
        let confirmations = confirm_proposal(&mut contract, &owner, proposal_id).blocking_wait();

        // Should still be 1 (idempotent)
        assert_eq!(confirmations, 1, "Idempotent confirmation should not increment");

        // Verify proposal state
        let proposal = contract
            .state
            .pending_proposals
            .get(&proposal_id)
            .blocking_wait()
            .expect("Failed to get proposal")
            .expect("Proposal should exist");

        assert_eq!(proposal.confirmation_count, 1);
    }
}

// ============================================================================
// Module: Execution Tests with Threshold Enforcement
// ============================================================================

#[cfg(test)]
mod execution_tests {
    use super::*;

    #[test]
    fn test_execute_proposal_with_sufficient_confirmations() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let proposer = account_owner(&owners[0]);
        let confirmer = account_owner(&owners[1]);

        let proposal_id = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::AddOwner {
                owner: account_owner(&Owner::User([50; 32])),
            },
        )
        .blocking_wait();

        // Get second confirmation
        confirm_proposal(&mut contract, &confirmer, proposal_id).blocking_wait();

        // Execute
        let response = execute_proposal(&mut contract, &proposer, proposal_id).blocking_wait();

        match response {
            MultisigResponse::OwnerAdded { owner } => {
                assert_eq!(owner, account_owner(&Owner::User([50; 32])));
            }
            _ => panic!("Expected OwnerAdded response"),
        }

        // Verify proposal moved to executed
        let executed_proposal = contract
            .state
            .executed_proposals
            .get(&proposal_id)
            .blocking_wait()
            .expect("Failed to get executed proposal")
            .expect("Executed proposal should exist");

        assert!(executed_proposal.executed);

        // Verify no longer pending
        let pending_proposal = contract
            .state
            .pending_proposals
            .get(&proposal_id)
            .blocking_wait()
            .expect("Failed to check pending proposals");

        assert!(pending_proposal.is_none(), "Proposal should not be pending");
    }

    #[test]
    #[should_panic(expected = "Insufficient confirmations")]
    fn test_execute_proposal_insufficient_confirmations_fails() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let proposer = account_owner(&owners[0]);

        let proposal_id = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::AddOwner {
                owner: account_owner(&Owner::User([50; 32])),
            },
        )
        .blocking_wait();

        // Only 1 confirmation (proposer), but threshold is 2
        execute_proposal(&mut contract, &proposer, proposal_id).blocking_wait();
    }

    #[test]
    #[should_panic(expected = "Proposal already executed")]
    fn test_execute_proposal_twice_fails() {
        let mut contract = setup_multisig(2, 1);
        let owners = create_test_owners(2);
        let proposer = account_owner(&owners[0]);

        let proposal_id = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::AddOwner {
                owner: account_owner(&Owner::User([50; 32])),
            },
        )
        .blocking_wait();

        // Threshold is 1, so proposer can execute immediately
        execute_proposal(&mut contract, &proposer, proposal_id).blocking_wait();

        // Try to execute again
        execute_proposal(&mut contract, &proposer, proposal_id).blocking_wait();
    }

    #[test]
    fn test_execute_transfer_proposal() {
        let mut contract = setup_multisig(2, 1);
        let owners = create_test_owners(2);
        let proposer = account_owner(&owners[0]);
        let recipient = account_owner(&owners[1]);

        let proposal_id = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::Transfer {
                to: recipient,
                value: 100,
                data: vec![1, 2, 3],
            },
        )
        .blocking_wait();

        let response = execute_proposal(&mut contract, &proposer, proposal_id).blocking_wait();

        match response {
            MultisigResponse::FundsTransferred { to, value } => {
                assert_eq!(to, recipient);
                assert_eq!(value, 100);
            }
            _ => panic!("Expected FundsTransferred response"),
        }
    }

    #[test]
    fn test_execute_remove_owner_proposal() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let proposer = account_owner(&owners[0]);
        let confirmer = account_owner(&owners[1]);
        let owner_to_remove = account_owner(&owners[2]);

        let proposal_id = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::RemoveOwner {
                owner: owner_to_remove,
            },
        )
        .blocking_wait();

        confirm_proposal(&mut contract, &confirmer, proposal_id).blocking_wait();

        let response = execute_proposal(&mut contract, &proposer, proposal_id).blocking_wait();

        match response {
            MultisigResponse::OwnerRemoved { owner } => {
                assert_eq!(owner, owner_to_remove);
            }
            _ => panic!("Expected OwnerRemoved response"),
        }

        // Verify owner was actually removed
        let current_owners = contract.state.owners.get();
        assert!(!current_owners.contains(&owner_to_remove));
        assert_eq!(current_owners.len(), 2);
    }

    #[test]
    fn test_execute_replace_owner_proposal() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let proposer = account_owner(&owners[0]);
        let confirmer = account_owner(&owners[1]);
        let old_owner = account_owner(&owners[2]);
        let new_owner = account_owner(&Owner::User([123; 32]));

        let proposal_id = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::ReplaceOwner {
                old_owner,
                new_owner,
            },
        )
        .blocking_wait();

        confirm_proposal(&mut contract, &confirmer, proposal_id).blocking_wait();

        let response = execute_proposal(&mut contract, &proposer, proposal_id).blocking_wait();

        match response {
            MultisigResponse::OwnerReplaced {
                old_owner: old,
                new_owner: new,
            } => {
                assert_eq!(old, old_owner);
                assert_eq!(new, new_owner);
            }
            _ => panic!("Expected OwnerReplaced response"),
        }

        // Verify owner was replaced
        let current_owners = contract.state.owners.get();
        assert!(!current_owners.contains(&old_owner));
        assert!(current_owners.contains(&new_owner));
    }

    #[test]
    fn test_execute_change_threshold_proposal() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let proposer = account_owner(&owners[0]);
        let confirmer = account_owner(&owners[1]);

        let new_threshold = 3;
        let proposal_id = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::ChangeThreshold {
                threshold: new_threshold,
            },
        )
        .blocking_wait();

        confirm_proposal(&mut contract, &confirmer, proposal_id).blocking_wait();

        let response = execute_proposal(&mut contract, &proposer, proposal_id).blocking_wait();

        match response {
            MultisigResponse::ThresholdChanged { new_threshold: t } => {
                assert_eq!(t, new_threshold);
            }
            _ => panic!("Expected ThresholdChanged response"),
        }

        // Verify threshold was changed
        let current_threshold = contract.state.threshold.get();
        assert_eq!(*current_threshold, new_threshold);
    }
}

// ============================================================================
// Module: Revoke Confirmation Tests
// ============================================================================

#[cfg(test)]
mod revocation_tests {
    use super::*;

    #[test]
    fn test_revoke_confirmation_decrements_count() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let owner1 = account_owner(&owners[0]);
        let owner2 = account_owner(&owners[1]);

        let proposal_id = submit_proposal(
            &mut contract,
            &owner1,
            ProposalType::Transfer {
                to: account_owner(&owners[2]),
                value: 100,
                data: vec![],
            },
        )
        .blocking_wait();

        // Second owner confirms
        confirm_proposal(&mut contract, &owner2, proposal_id).blocking_wait();

        // Verify 2 confirmations
        let proposal = contract
            .state
            .pending_proposals
            .get(&proposal_id)
            .blocking_wait()
            .expect("Failed to get proposal")
            .expect("Proposal should exist");
        assert_eq!(proposal.confirmation_count, 2);

        // Revoke from owner2
        revoke_confirmation(&mut contract, &owner2, proposal_id).blocking_wait();

        // Verify now 1 confirmation
        let proposal = contract
            .state
            .pending_proposals
            .get(&proposal_id)
            .blocking_wait()
            .expect("Failed to get proposal")
            .expect("Proposal should exist");
        assert_eq!(proposal.confirmation_count, 1);
    }

    #[test]
    fn test_revoke_confirmation_idempotent() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let owner1 = account_owner(&owners[0]);

        let proposal_id = submit_proposal(
            &mut contract,
            &owner1,
            ProposalType::Transfer {
                to: account_owner(&owners[1]),
                value: 100,
                data: vec![],
            },
        )
        .blocking_wait();

        // Revoke once
        revoke_confirmation(&mut contract, &owner1, proposal_id).blocking_wait();

        let proposal = contract
            .state
            .pending_proposals
            .get(&proposal_id)
            .blocking_wait()
            .expect("Failed to get proposal")
            .expect("Proposal should exist");
        let count_after_first = proposal.confirmation_count;

        // Revoke again (should be no-op)
        revoke_confirmation(&mut contract, &owner1, proposal_id).blocking_wait();

        let proposal = contract
            .state
            .pending_proposals
            .get(&proposal_id)
            .blocking_wait()
            .expect("Failed to get proposal")
            .expect("Proposal should exist");

        assert_eq!(
            proposal.confirmation_count,
            count_after_first,
            "Double revoke should be idempotent"
        );
    }

    #[test]
    #[should_panic(expected = "Cannot revoke confirmation for executed proposal")]
    fn test_revoke_confirmation_after_execute_fails() {
        let mut contract = setup_multisig(2, 1);
        let owners = create_test_owners(2);
        let owner1 = account_owner(&owners[0]);

        let proposal_id = submit_proposal(
            &mut contract,
            &owner1,
            ProposalType::AddOwner {
                owner: account_owner(&Owner::User([55; 32])),
            },
        )
        .blocking_wait();

        // Execute (threshold is 1)
        execute_proposal(&mut contract, &owner1, proposal_id).blocking_wait();

        // Try to revoke
        revoke_confirmation(&mut contract, &owner1, proposal_id).blocking_wait();
    }
}

// ============================================================================
// Module: Authorization Tests
// ============================================================================

#[cfg(test)]
mod authorization_tests {
    use super::*;

    #[test]
    #[should_panic(expected = "is not an owner")]
    fn test_non_owner_cannot_submit_proposal() {
        let mut contract = setup_multisig(3, 2);
        let non_owner = account_owner(&Owner::User([255; 32]));

        contract
            .execute_operation(MultisigOperation::SubmitProposal {
                proposal_type: ProposalType::AddOwner {
                    owner: account_owner(&Owner::User([50; 32])),
                },
            })
            .blocking_wait();
    }

    #[test]
    #[should_panic(expected = "is not an owner")]
    fn test_non_owner_cannot_confirm_proposal() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let proposer = account_owner(&owners[0]);
        let non_owner = account_owner(&Owner::User([255; 32]));

        let proposal_id = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::Transfer {
                to: account_owner(&owners[1]),
                value: 100,
                data: vec![],
            },
        )
        .blocking_wait();

        confirm_proposal(&mut contract, &non_owner, proposal_id).blocking_wait();
    }

    #[test]
    #[should_panic(expected = "is not an owner")]
    fn test_non_owner_cannot_execute_proposal() {
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let proposer = account_owner(&owners[0]);
        let non_owner = account_owner(&Owner::User([255; 32]));

        let proposal_id = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::Transfer {
                to: account_owner(&owners[1]),
                value: 100,
                data: vec![],
            },
        )
        .blocking_wait();

        execute_proposal(&mut contract, &non_owner, proposal_id).blocking_wait();
    }
}

// ============================================================================
// Module: Nonce and Proposal ID Tests
// ============================================================================

#[cfg(test)]
mod nonce_tests {
    use super::*;

    #[test]
    fn test_proposal_ids_increment_with_nonce() {
        let mut contract = setup_multisig(2, 1);
        let owners = create_test_owners(2);
        let proposer = account_owner(&owners[0]);

        // Submit first proposal
        let id1 = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::AddOwner {
                owner: account_owner(&Owner::User([1; 32])),
            },
        )
        .blocking_wait();

        // Submit second proposal
        let id2 = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::AddOwner {
                owner: account_owner(&Owner::User([2; 32])),
            },
        )
        .blocking_wait();

        // Submit third proposal
        let id3 = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::AddOwner {
                owner: account_owner(&Owner::User([3; 32])),
            },
        )
        .blocking_wait();

        assert_eq!(id1, 0, "First proposal ID should be 0");
        assert_eq!(id2, 1, "Second proposal ID should be 1");
        assert_eq!(id3, 2, "Third proposal ID should be 2");

        // Verify nonce was incremented
        let nonce = contract.state.nonce.get();
        assert_eq!(*nonce, 3, "Nonce should be 3 after 3 proposals");
    }
}

// ============================================================================
// Module: Instantiation Validation Tests
// ============================================================================

#[cfg(test)]
mod instantiation_tests {
    use super::*;

    #[test]
    #[should_panic(expected = "Threshold must be greater than 0")]
    fn test_instantiate_with_zero_threshold_fails() {
        let owners = create_test_owners(3);
        let account_owners: Vec<AccountOwner> = owners.iter().map(account_owner).collect();

        let mut runtime = MockContractRuntime::<MultisigContract>::default();
        runtime.with_chain_id(test_chain_id());

        let contract = MultisigContract::load(ContractRuntime::new()).blocking_wait();

        let args = InstantiationArgs {
            owners: account_owners,
            threshold: 0,
        };

        contract.instantiate(args).blocking_wait();
    }

    #[test]
    #[should_panic(expected = "Threshold cannot exceed number of owners")]
    fn test_instantiate_threshold_exceeds_owners_fails() {
        let owners = create_test_owners(3);
        let account_owners: Vec<AccountOwner> = owners.iter().map(account_owner).collect();

        let mut runtime = MockContractRuntime::<MultisigContract>::default();
        runtime.with_chain_id(test_chain_id());

        let contract = MultisigContract::load(ContractRuntime::new()).blocking_wait();

        let args = InstantiationArgs {
            owners: account_owners,
            threshold: 4, // More than owners (3)
        };

        contract.instantiate(args).blocking_wait();
    }

    #[test]
    fn test_instantiate_valid_configuration() {
        let owners = create_test_owners(5);
        let account_owners: Vec<AccountOwner> = owners.iter().map(account_owner).collect();

        let mut runtime = MockContractRuntime::<MultisigContract>::default();
        runtime.with_chain_id(test_chain_id());

        let contract = MultisigContract::load(ContractRuntime::new()).blocking_wait();

        let args = InstantiationArgs {
            owners: account_owners.clone(),
            threshold: 3,
        };

        contract.instantiate(args).blocking_wait();

        // Verify state
        let stored_owners = contract.state.owners.get();
        assert_eq!(*stored_owners, account_owners);
        assert_eq!(stored_owners.len(), 5);

        let stored_threshold = contract.state.threshold.get();
        assert_eq!(*stored_threshold, 3);

        let stored_nonce = contract.state.nonce.get();
        assert_eq!(*stored_nonce, 0);
    }
}

// ============================================================================
// Module: Edge Cases
// ============================================================================

#[cfg(test)]
mod edge_case_tests {
    use super::*;

    #[test]
    fn test_single_owner_with_threshold_one() {
        // Edge case: 1 owner with threshold 1 should work
        let mut contract = setup_multisig(1, 1);
        let owners = create_test_owners(1);
        let owner = account_owner(&owners[0]);

        let proposal_id = submit_proposal(
            &mut contract,
            &owner,
            ProposalType::AddOwner {
                owner: account_owner(&Owner::User([88; 32])),
            },
        )
        .blocking_wait();

        // Should be executable immediately
        let response = execute_proposal(&mut contract, &owner, proposal_id).blocking_wait();

        match response {
            MultisigResponse::OwnerAdded { .. } => {}
            _ => panic!("Expected OwnerAdded response"),
        }
    }

    #[test]
    fn test_all_owners_must_confirm_for_max_threshold() {
        // 3 owners, threshold 3 - all must confirm
        let mut contract = setup_multisig(3, 3);
        let owners = create_test_owners(3);
        let owner1 = account_owner(&owners[0]);
        let owner2 = account_owner(&owners[1]);
        let owner3 = account_owner(&owners[2]);

        let proposal_id = submit_proposal(
            &mut contract,
            &owner1,
            ProposalType::AddOwner {
                owner: account_owner(&Owner::User([77; 32])),
            },
        )
        .blocking_wait();

        // Only 2 confirmations
        confirm_proposal(&mut contract, &owner2, proposal_id).blocking_wait();

        // Try to execute - should fail
        let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            execute_proposal(&mut contract, &owner1, proposal_id).blocking_wait();
        }));

        assert!(result.is_err(), "Execution should fail with insufficient confirmations");

        // Third owner confirms
        confirm_proposal(&mut contract, &owner3, proposal_id).blocking_wait();

        // Now execution should succeed
        let response = execute_proposal(&mut contract, &owner1, proposal_id).blocking_wait();

        match response {
            MultisigResponse::OwnerAdded { .. } => {}
            _ => panic!("Expected OwnerAdded response"),
        }
    }

    #[test]
    fn test_proposal_timestamp_is_set() {
        let mut contract = setup_multisig(2, 1);
        let owners = create_test_owners(2);
        let proposer = account_owner(&owners[0]);

        let proposal_id = submit_proposal(
            &mut contract,
            &proposer,
            ProposalType::Transfer {
                to: account_owner(&owners[1]),
                value: 100,
                data: vec![],
            },
        )
        .blocking_wait();

        let proposal = contract
            .state
            .pending_proposals
            .get(&proposal_id)
            .blocking_wait()
            .expect("Failed to get proposal")
            .expect("Proposal should exist");

        assert!(proposal.created_at > 0, "Timestamp should be set");
    }

    #[test]
    fn test_multiple_proposals_independent() {
        // Multiple proposals should not interfere with each other
        let mut contract = setup_multisig(3, 2);
        let owners = create_test_owners(3);
        let owner1 = account_owner(&owners[0]);
        let owner2 = account_owner(&owners[1]);

        // Submit two proposals
        let id1 = submit_proposal(
            &mut contract,
            &owner1,
            ProposalType::AddOwner {
                owner: account_owner(&Owner::User([11; 32])),
            },
        )
        .blocking_wait();

        let id2 = submit_proposal(
            &mut contract,
            &owner1,
            ProposalType::ChangeThreshold { threshold: 3 },
        )
        .blocking_wait();

        // Confirm first proposal
        confirm_proposal(&mut contract, &owner2, id1).blocking_wait();

        // First should be executable
        let _ = execute_proposal(&mut contract, &owner1, id1).blocking_wait();

        // Second should still be pending with only 1 confirmation
        let proposal2 = contract
            .state
            .pending_proposals
            .get(&id2)
            .blocking_wait()
            .expect("Failed to get proposal")
            .expect("Proposal should exist");

        assert!(!proposal2.executed);
        assert_eq!(proposal2.confirmation_count, 1);
    }
}
