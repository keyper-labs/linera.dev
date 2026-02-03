// Copyright (c) 2025 PalmeraDAO
// SPDX-License-Identifier: MIT

//! Multisig application state

use linera_sdk::views::{linera_views, MapView, RegisterView, RootView, ViewStorageContext};
use linera_sdk::linera_base_types::AccountOwner;

// Re-export ProposalType from the main lib to avoid duplication
pub use linera_multisig::ProposalType;

/// Multisig wallet state
#[derive(RootView)]
#[view(context = ViewStorageContext)]
pub struct MultisigState {
    /// Current owners of the multisig wallet
    pub owners: RegisterView<Vec<AccountOwner>>,
    /// Number of confirmations required for execution
    pub threshold: RegisterView<u64>,
    /// Proposal nonce (unique ID for each proposal)
    pub nonce: RegisterView<u64>,
    /// Pending proposals by ID
    pub pending_proposals: MapView<u64, Proposal>,
    /// Confirmations per owner: owner -> list of proposal IDs they've confirmed
    pub confirmations: MapView<AccountOwner, Vec<u64>>,
    /// Executed proposals (for historical record)
    pub executed_proposals: MapView<u64, Proposal>,
}

/// A multisig proposal (can be transaction or governance operation)
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct Proposal {
    /// Unique proposal ID
    pub id: u64,
    /// Type of proposal
    pub proposal_type: ProposalType,
    /// Owner who created the proposal
    pub proposer: AccountOwner,
    /// Number of confirmations received
    pub confirmation_count: u64,
    /// Whether the proposal has been executed
    pub executed: bool,
    /// Timestamp when proposal was created (for expiration)
    pub created_at: u64,
}
