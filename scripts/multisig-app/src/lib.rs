// Copyright (c) 2025 PalmeraDAO
// SPDX-License-Identifier: MIT

/*! ABI for the Linera Multisig Application */

use async_graphql::{Request, Response};
use linera_sdk::linera_base_types::{AccountOwner, ContractAbi, ServiceAbi};
use serde::{Deserialize, Serialize};

// Type alias for convenience
pub type Owner = AccountOwner;

/// ABI marker type for the multisig application
pub struct MultisigAbi;

/// Multisig operations - All operations now go through proposal flow
#[derive(Debug, Deserialize, Serialize)]
pub enum MultisigOperation {
    /// Submit a new proposal (transfer, add owner, remove owner, etc.)
    SubmitProposal {
        /// Type of proposal
        proposal_type: ProposalType,
    },

    /// Confirm a pending proposal
    ConfirmProposal {
        /// Proposal ID
        proposal_id: u64,
    },

    /// Execute a confirmed proposal
    ExecuteProposal {
        /// Proposal ID
        proposal_id: u64,
    },

    /// Revoke a confirmation
    RevokeConfirmation {
        /// Proposal ID
        proposal_id: u64,
    },
}

/// Type of proposal that can be submitted
#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
pub enum ProposalType {
    /// Transfer funds to an address
    Transfer {
        /// Destination address
        to: AccountOwner,
        /// Amount/value to send
        value: u64,
        /// Transaction data (calldata, function selector, etc.)
        data: Vec<u8>,
    },

    /// Add a new owner
    AddOwner {
        /// New owner address
        owner: AccountOwner,
    },

    /// Remove an owner
    RemoveOwner {
        /// Owner address to remove
        owner: AccountOwner,
    },

    /// Replace an owner
    ReplaceOwner {
        /// Old owner to replace
        old_owner: AccountOwner,
        /// New owner address
        new_owner: AccountOwner,
    },

    /// Change threshold
    ChangeThreshold {
        /// New threshold value
        threshold: u64,
    },
}

impl ContractAbi for MultisigAbi {
    type Operation = MultisigOperation;
    type Response = MultisigResponse;
}

impl ServiceAbi for MultisigAbi {
    type Query = Request;
    type QueryResponse = Response;
}

/// Response types for multisig operations
#[derive(Debug, Clone, Deserialize, Serialize)]
pub enum MultisigResponse {
    /// Proposal submitted successfully
    ProposalSubmitted {
        /// ID of the submitted proposal
        proposal_id: u64,
    },
    /// Proposal confirmed
    ProposalConfirmed {
        /// ID of the confirmed proposal
        proposal_id: u64,
        /// Current number of confirmations
        confirmations: u64,
    },
    /// Proposal executed
    ProposalExecuted {
        /// ID of the executed proposal
        proposal_id: u64,
    },
    /// Confirmation revoked
    ConfirmationRevoked {
        /// ID of the proposal
        proposal_id: u64,
    },
    /// Owner added (after proposal execution)
    OwnerAdded {
        /// Address of the added owner
        owner: AccountOwner,
    },
    /// Owner removed (after proposal execution)
    OwnerRemoved {
        /// Address of the removed owner
        owner: AccountOwner,
    },
    /// Threshold changed (after proposal execution)
    ThresholdChanged {
        /// New threshold value
        new_threshold: u64,
    },
    /// Owner replaced (after proposal execution)
    OwnerReplaced {
        /// Address of the replaced owner
        old_owner: AccountOwner,
        /// Address of the new owner
        new_owner: AccountOwner,
    },
    /// Funds transferred (after proposal execution)
    FundsTransferred {
        /// Destination address
        to: AccountOwner,
        /// Amount transferred
        value: u64,
    },
}

/// Proposal view for GraphQL queries
#[derive(Debug, Clone, async_graphql::SimpleObject, serde::Serialize, serde::Deserialize)]
pub struct ProposalView {
    /// Proposal ID
    pub id: u64,
    /// Type of proposal (as string representation)
    pub proposal_type: String,
    /// Owner who created the proposal
    pub proposer: Owner,
    /// Number of confirmations
    pub confirmation_count: u64,
    /// Whether executed
    pub executed: bool,
    /// Creation timestamp
    pub created_at: u64,
}
