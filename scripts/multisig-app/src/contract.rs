// Copyright (c) 2025 PalmeraDAO
// SPDX-License-Identifier: MIT

#![cfg_attr(target_arch = "wasm32", no_main)]

mod state;

use linera_sdk::{
    linera_base_types::{AccountOwner, Amount, WithContractAbi},
    views::{RootView, View},
    Contract, ContractRuntime,
};
use log::{info, warn};

use linera_multisig::{MultisigAbi, MultisigOperation, MultisigResponse, ProposalType};

use self::state::{MultisigState, Proposal};

/// Multisig contract implementation
pub struct MultisigContract {
    state: MultisigState,
    runtime: ContractRuntime<Self>,
}

// Required macro export for Wasm compilation
linera_sdk::contract!(MultisigContract);

impl WithContractAbi for MultisigContract {
    type Abi = MultisigAbi;
}

impl Contract for MultisigContract {
    type Message = ();
    type InstantiationArgument = InstantiationArgs;
    type Parameters = ();
    type EventValue = ();

    async fn load(runtime: ContractRuntime<Self>) -> Self {
        let state = MultisigState::load(runtime.root_view_storage_context())
            .await
            .expect("Failed to load state");
        MultisigContract { state, runtime }
    }

    async fn instantiate(&mut self, args: InstantiationArgs) {
        // Validate that the application parameters were configured correctly.
        self.runtime.application_parameters();

        // Initialize owners
        self.state.owners.set(args.owners.clone());

        // Validate and initialize threshold
        if args.threshold == 0 {
            panic!("Threshold must be greater than 0");
        }
        if args.threshold as usize > args.owners.len() {
            panic!("Threshold cannot exceed number of owners");
        }
        self.state.threshold.set(args.threshold);

        // Initialize nonce to 0
        self.state.nonce.set(0);

        // Set proposal lifetime (default: 7 days = 604800 seconds) - Safe standard
        let lifetime = args.proposal_lifetime.unwrap_or(604800);
        self.state.proposal_lifetime.set(lifetime);

        // Set time-delay (default: 0 = disabled, Safe native behavior)
        let delay = args.time_delay.unwrap_or(0);
        self.state.time_delay.set(delay);

        info!(
            "Multisig instantiated: {} owners, threshold={}, lifetime={}s, delay={}s",
            args.owners.len(),
            args.threshold,
            lifetime,
            delay
        );
    }

    async fn execute_operation(&mut self, operation: MultisigOperation) -> MultisigResponse {
        let caller = self
            .runtime
            .authenticated_signer()
            .expect("Operation must be authenticated");

        match operation {
            MultisigOperation::SubmitProposal { proposal_type } => {
                self.submit_proposal(caller, proposal_type).await
            }

            MultisigOperation::ConfirmProposal { proposal_id } => {
                self.confirm_proposal(caller, proposal_id).await
            }

            MultisigOperation::ExecuteProposal { proposal_id } => {
                self.execute_proposal(caller, proposal_id).await
            }

            MultisigOperation::RevokeConfirmation { proposal_id } => {
                self.revoke_confirmation(caller, proposal_id).await
            }
        }
    }

    async fn execute_message(&mut self, _message: ()) {
        panic!("Multisig application doesn't support cross-chain messages yet");
    }

    async fn store(mut self) {
        self.state
            .save()
            .await
            .expect("Failed to save state");
    }
}

impl MultisigContract {
    /// Submit a new proposal (transfer, governance, etc.)
    async fn submit_proposal(
        &mut self,
        caller: AccountOwner,
        proposal_type: ProposalType,
    ) -> MultisigResponse {
        // Verify caller is an owner
        self.ensure_is_owner(&caller);

        // Validate proposal
        self.validate_proposal(&proposal_type).await;

        // Get current nonce and increment
        let proposal_id = *self.state.nonce.get();
        self.state.nonce.set(proposal_id + 1);

        // Get current timestamp
        let created_at = self.runtime.system_time().micros();

        // Calculate expiration (Safe standard: 7+ days)
        let lifetime_seconds = *self.state.proposal_lifetime.get();
        let expires_at = created_at + (lifetime_seconds * 1_000_000);

        // Create proposal (executable_after set to 0 initially, updated when threshold reached)
        let proposal = Proposal {
            id: proposal_id,
            proposal_type,
            proposer: caller,
            confirmation_count: 0,
            executed: false,
            created_at,
            expires_at,
            executable_after: 0, // Will be set when threshold reached (if time_delay > 0)
        };

        // Store proposal
        self.state
            .pending_proposals
            .insert(&proposal_id, proposal)
            .expect("Failed to store proposal");

        // Auto-confirm from submitter
        self.confirm_proposal_internal(caller, proposal_id).await;

        info!(
            "Proposal {} submitted by {:?}",
            proposal_id, caller
        );

        MultisigResponse::ProposalSubmitted { proposal_id }
    }

    /// Validate a proposal before submission
    async fn validate_proposal(&self, proposal_type: &ProposalType) {
        match proposal_type {
            ProposalType::Transfer { value, .. } => {
                if *value == 0 {
                    panic!("Transfer amount must be greater than 0");
                }
            }
            ProposalType::AddOwner { owner } => {
                let owners = self.state.owners.get();
                if owners.contains(owner) {
                    panic!("Owner already exists");
                }
            }
            ProposalType::RemoveOwner { owner } => {
                let owners = self.state.owners.get();
                if !owners.contains(owner) {
                    panic!("Owner does not exist");
                }
                let threshold = *self.state.threshold.get();
                // Ensure we don't go below threshold after removal
                if owners.len() - 1 < threshold as usize {
                    panic!("Cannot remove owner: would make threshold impossible to reach");
                }
            }
            ProposalType::ReplaceOwner { old_owner, new_owner } => {
                let owners = self.state.owners.get();
                if !owners.contains(old_owner) {
                    panic!("Old owner does not exist");
                }
                if owners.contains(new_owner) {
                    panic!("New owner already exists");
                }
            }
            ProposalType::ChangeThreshold { threshold } => {
                if *threshold == 0 {
                    panic!("Threshold cannot be zero");
                }
                let owners = self.state.owners.get();
                if *threshold as usize > owners.len() {
                    panic!("Threshold cannot exceed number of owners");
                }
            }
        }
    }

    /// Confirm a pending proposal
    async fn confirm_proposal(&mut self, caller: AccountOwner, proposal_id: u64) -> MultisigResponse {
        self.ensure_is_owner(&caller);

        let confirmations = self.confirm_proposal_internal(caller, proposal_id).await;

        MultisigResponse::ProposalConfirmed {
            proposal_id,
            confirmations,
        }
    }

    /// Internal confirmation logic
    async fn confirm_proposal_internal(&mut self, caller: AccountOwner, proposal_id: u64) -> u64 {
        let mut proposal = self
            .state
            .pending_proposals
            .get(&proposal_id)
            .await
            .expect("Failed to get proposal")
            .unwrap_or_else(|| panic!("Proposal {} not found", proposal_id));

        if proposal.executed {
            panic!("Proposal already executed");
        }

        // Get existing confirmations for this owner
        let mut confirmed_proposals = self.state.confirmations.get(&caller).await.unwrap().unwrap_or_default();

        // Check if already confirmed
        if confirmed_proposals.contains(&proposal_id) {
            warn!("Owner {:?} already confirmed proposal {}", caller, proposal_id);
            return proposal.confirmation_count;
        }

        // Add confirmation
        confirmed_proposals.push(proposal_id);
        self.state.confirmations.insert(&caller, confirmed_proposals)
            .expect("Failed to store confirmations");

        // Update confirmation count
        proposal.confirmation_count += 1;

        // Set executable_after when threshold is reached (if time_delay > 0)
        let threshold = *self.state.threshold.get();
        let time_delay = *self.state.time_delay.get();
        if proposal.confirmation_count == threshold && time_delay > 0 {
            let now = self.runtime.system_time().micros();
            proposal.executable_after = now + (time_delay * 1_000_000);
            info!(
                "Proposal {} reached threshold, executable in {} seconds",
                proposal_id, time_delay
            );
        }

        let confirmation_count = proposal.confirmation_count;
        self.state
            .pending_proposals
            .insert(&proposal_id, proposal)
            .expect("Failed to store proposal");

        info!(
            "Proposal {} confirmed by {:?} (total: {})",
            proposal_id, caller, confirmation_count
        );

        confirmation_count
    }

    /// Execute a confirmed proposal
    async fn execute_proposal(&mut self, caller: AccountOwner, proposal_id: u64) -> MultisigResponse {
        self.ensure_is_owner(&caller);

        let proposal = self
            .state
            .pending_proposals
            .get(&proposal_id)
            .await
            .expect("Failed to get proposal")
            .unwrap_or_else(|| panic!("Proposal {} not found", proposal_id));

        if proposal.executed {
            panic!("Proposal already executed");
        }

        // Check expiration (Safe standard)
        let now = self.runtime.system_time().micros();
        if now > proposal.expires_at {
            panic!(
                "Proposal expired: current time {} > expiration {}",
                now, proposal.expires_at
            );
        }

        let threshold = *self.state.threshold.get();

        if proposal.confirmation_count < threshold {
            panic!(
                "Insufficient confirmations: {} < {} (required)",
                proposal.confirmation_count, threshold
            );
        }

        // Check time-delay if configured (optional feature)
        let time_delay = *self.state.time_delay.get();
        if time_delay > 0 && now < proposal.executable_after {
            let wait_seconds = (proposal.executable_after - now) / 1_000_000;
            panic!(
                "Time-delay not met: must wait {} more seconds (configure time_delay=0 to disable)",
                wait_seconds
            );
        }

        // Execute based on proposal type
        let response = match &proposal.proposal_type {
            ProposalType::Transfer { to, value, .. } => {
                self.execute_transfer(caller, *to, *value).await
            }
            ProposalType::AddOwner { owner } => {
                self.execute_add_owner(*owner).await
            }
            ProposalType::RemoveOwner { owner } => {
                self.execute_remove_owner(*owner).await
            }
            ProposalType::ReplaceOwner { old_owner, new_owner } => {
                self.execute_replace_owner(*old_owner, *new_owner).await
            }
            ProposalType::ChangeThreshold { threshold } => {
                self.execute_change_threshold(*threshold).await
            }
        };

        // Mark as executed and move to executed proposals
        let mut executed_proposal = proposal.clone();
        executed_proposal.executed = true;
        self.state
            .executed_proposals
            .insert(&proposal_id, executed_proposal)
            .expect("Failed to store executed proposal");
        
        // Remove from pending
        self.state.pending_proposals.remove(&proposal_id)
            .expect("Failed to remove pending proposal");

        info!(
            "Proposal {} executed by {:?}",
            proposal_id, caller
        );

        response
    }

    /// Execute a transfer
    async fn execute_transfer(&mut self, source: AccountOwner, to: AccountOwner, value: u64) -> MultisigResponse {
        // Convert u64 to Amount (from_tokens expects u128)
        let amount = Amount::from_tokens(value.into());

        // Validate balance before transfer (prevent state corruption)
        let contract_balance = self.runtime.chain_balance();
        if contract_balance < amount {
            panic!(
                "Insufficient balance: required={}, available={}",
                amount, contract_balance
            );
        }

        // Execute the actual transfer from contract to destination
        let chain_id = self.runtime.chain_id();
        let destination = linera_sdk::linera_base_types::Account::new(chain_id, to);
        self.runtime.transfer(source, destination, amount);

        // Validate post-transfer balance (ensure transfer succeeded)
        let new_balance = self.runtime.chain_balance();
        if new_balance >= contract_balance {
            panic!("Transfer validation failed - balance did not decrease");
        }

        info!("Transferred {} tokens to {:?}", value, to);

        MultisigResponse::FundsTransferred { to, value }
    }

    /// Execute add owner
    async fn execute_add_owner(&mut self, owner: AccountOwner) -> MultisigResponse {
        let mut owners = self.state.owners.get().clone();
        
        if owners.contains(&owner) {
            panic!("Owner already exists");
        }
        
        owners.push(owner);
        self.state.owners.set(owners);
        
        info!("Owner {:?} added", owner);
        
        MultisigResponse::OwnerAdded { owner }
    }

    /// Execute remove owner
    async fn execute_remove_owner(&mut self, owner: AccountOwner) -> MultisigResponse {
        let mut owners = self.state.owners.get().clone();
        
        if let Some(pos) = owners.iter().position(|o| o == &owner) {
            owners.remove(pos);
            
            // Ensure we don't go below threshold
            let threshold = *self.state.threshold.get();
            if owners.len() < threshold as usize {
                panic!("Cannot remove owner: would go below threshold");
            }
            
            self.state.owners.set(owners);
            
            info!("Owner {:?} removed", owner);
            
            MultisigResponse::OwnerRemoved { owner }
        } else {
            panic!("Owner not found");
        }
    }

    /// Execute replace owner
    async fn execute_replace_owner(
        &mut self,
        old_owner: AccountOwner,
        new_owner: AccountOwner,
    ) -> MultisigResponse {
        let mut owners = self.state.owners.get().clone();
        
        if let Some(pos) = owners.iter().position(|o| o == &old_owner) {
            if owners.contains(&new_owner) {
                panic!("New owner already exists");
            }
            
            owners[pos] = new_owner;
            self.state.owners.set(owners);
            
            info!("Owner {:?} replaced with {:?}", old_owner, new_owner);
            
            MultisigResponse::OwnerReplaced { old_owner, new_owner }
        } else {
            panic!("Old owner not found");
        }
    }

    /// Execute change threshold
    async fn execute_change_threshold(&mut self, threshold: u64) -> MultisigResponse {
        let owners = self.state.owners.get();
        
        if threshold == 0 {
            panic!("Threshold cannot be zero");
        }
        
        if threshold as usize > owners.len() {
            panic!("Threshold cannot exceed number of owners");
        }
        
        self.state.threshold.set(threshold);
        
        info!("Threshold changed to {}", threshold);
        
        MultisigResponse::ThresholdChanged { new_threshold: threshold }
    }

    /// Revoke a confirmation
    async fn revoke_confirmation(&mut self, caller: AccountOwner, proposal_id: u64) -> MultisigResponse {
        self.ensure_is_owner(&caller);

        let mut proposal = self
            .state
            .pending_proposals
            .get(&proposal_id)
            .await
            .expect("Failed to get proposal")
            .unwrap_or_else(|| panic!("Proposal {} not found", proposal_id));

        if proposal.executed {
            panic!("Cannot revoke confirmation for executed proposal");
        }

        let mut confirmed_proposals = self.state.confirmations.get(&caller).await.unwrap().unwrap_or_default();

        if let Some(pos) = confirmed_proposals.iter().position(|&id| id == proposal_id) {
            confirmed_proposals.remove(pos);
            self.state.confirmations.insert(&caller, confirmed_proposals)
                .expect("Failed to store confirmations");

            proposal.confirmation_count = proposal.confirmation_count.saturating_sub(1);
            self.state
                .pending_proposals
                .insert(&proposal_id, proposal)
                .expect("Failed to store proposal");

            info!(
                "Confirmation revoked by {:?} for proposal {}",
                caller, proposal_id
            );

            MultisigResponse::ConfirmationRevoked { proposal_id }
        } else {
            warn!("Owner {:?} has not confirmed proposal {}", caller, proposal_id);
            MultisigResponse::ConfirmationRevoked { proposal_id }
        }
    }

    /// Ensure the caller is an owner
    fn ensure_is_owner(&self, caller: &AccountOwner) {
        let owners = self.state.owners.get();
        if !owners.contains(caller) {
            panic!("Caller {:?} is not an owner", caller);
        }
    }
}

/// Instantiation arguments for the multisig
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct InstantiationArgs {
    /// Initial owners
    pub owners: Vec<AccountOwner>,
    /// Number of confirmations required
    pub threshold: u64,
    /// Proposal lifetime in seconds (optional, default: 7 days = 604800s)
    pub proposal_lifetime: Option<u64>,
    /// Time-delay in seconds before execution (optional, default: 0 = disabled, Safe native)
    pub time_delay: Option<u64>,
}
