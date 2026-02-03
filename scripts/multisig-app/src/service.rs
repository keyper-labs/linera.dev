// Copyright (c) 2025 PalmeraDAO
// SPDX-License-Identifier: MIT

#![cfg_attr(target_arch = "wasm32", no_main)]

use std::sync::Arc;

use async_graphql::{Context, EmptyMutation, EmptySubscription, Object, Request, Response, Result, Schema};
use linera_sdk::{
    linera_base_types::WithServiceAbi,
    views::View,
    Service, ServiceRuntime,
};
use linera_multisig::{MultisigAbi, Owner, ProposalView};

mod state;
use state::{MultisigState, Proposal, ProposalType};

/// Multisig service implementation
pub struct MultisigService {
    state: Arc<MultisigState>,
}

linera_sdk::service!(MultisigService);

impl WithServiceAbi for MultisigService {
    type Abi = MultisigAbi;
}

impl Service for MultisigService {
    type Parameters = ();

    async fn new(runtime: ServiceRuntime<Self>) -> Self {
        let state = MultisigState::load(runtime.root_view_storage_context())
            .await
            .expect("Failed to load state");
        MultisigService {
            state: Arc::new(state),
        }
    }

    async fn handle_query(&self, request: Request) -> Response {
        let schema = Schema::build(
            QueryRoot,
            EmptyMutation,
            EmptySubscription,
        )
        .data(self.state.clone())
        .finish();
        schema.execute(request).await
    }
}

/// Query root for GraphQL API
pub struct QueryRoot;

#[Object]
impl QueryRoot {
    /// Get the list of current owners
    async fn owners(&self, ctx: &Context<'_>) -> Result<Vec<Owner>> {
        let state = ctx.data::<Arc<MultisigState>>()?;
        Ok(state.owners.get().clone())
    }

    /// Get the current threshold
    async fn threshold(&self, ctx: &Context<'_>) -> Result<u64> {
        let state = ctx.data::<Arc<MultisigState>>()?;
        Ok(*state.threshold.get())
    }

    /// Get the current nonce (next proposal ID)
    async fn nonce(&self, ctx: &Context<'_>) -> Result<u64> {
        let state = ctx.data::<Arc<MultisigState>>()?;
        Ok(*state.nonce.get())
    }

    /// Get a proposal by ID
    async fn proposal(&self, ctx: &Context<'_>, id: u64) -> Result<Option<ProposalView>> {
        let state = ctx.data::<Arc<MultisigState>>()?;
        
        // Check pending proposals first
        if let Some(proposal) = state.pending_proposals.get(&id).await? {
            return Ok(Some(proposal_to_view(proposal)));
        }
        
        // Then check executed proposals
        if let Some(proposal) = state.executed_proposals.get(&id).await? {
            return Ok(Some(proposal_to_view(proposal)));
        }
        
        Ok(None)
    }

    /// Get all pending proposals
    async fn pending_proposals(&self, ctx: &Context<'_>) -> Result<Vec<ProposalView>> {
        let state = ctx.data::<Arc<MultisigState>>()?;
        let mut proposals = Vec::new();
        
        // Iterate through all pending proposals
        // MapView doesn't have iter(), so we get all indices and fetch each
        let indices = state.pending_proposals.indices().await?;
        for key in indices {
            if let Some(proposal) = state.pending_proposals.get(&key).await? {
                proposals.push(proposal_to_view(proposal));
            }
        }
        
        Ok(proposals)
    }

    /// Get all executed proposals
    async fn executed_proposals(&self, ctx: &Context<'_>) -> Result<Vec<ProposalView>> {
        let state = ctx.data::<Arc<MultisigState>>()?;
        let mut proposals = Vec::new();
        
        // Iterate through all executed proposals
        // MapView doesn't have iter(), so we get all indices and fetch each
        let indices = state.executed_proposals.indices().await?;
        for key in indices {
            if let Some(proposal) = state.executed_proposals.get(&key).await? {
                proposals.push(proposal_to_view(proposal));
            }
        }
        
        Ok(proposals)
    }

    /// Check if an owner has confirmed a proposal
    async fn has_confirmed(
        &self,
        ctx: &Context<'_>,
        owner: Owner,
        proposal_id: u64,
    ) -> Result<bool> {
        let state = ctx.data::<Arc<MultisigState>>()?;
        let confirmed_proposals = state.confirmations.get(&owner).await?.unwrap_or_default();
        Ok(confirmed_proposals.contains(&proposal_id))
    }

    /// Get the number of confirmations for a proposal
    async fn confirmation_count(&self, ctx: &Context<'_>, proposal_id: u64) -> Result<u64> {
        let state = ctx.data::<Arc<MultisigState>>()?;
        
        if let Some(proposal) = state.pending_proposals.get(&proposal_id).await? {
            Ok(proposal.confirmation_count)
        } else if let Some(proposal) = state.executed_proposals.get(&proposal_id).await? {
            Ok(proposal.confirmation_count)
        } else {
            Ok(0)
        }
    }

    /// Get proposals where an owner has confirmed
    async fn proposals_confirmed_by(
        &self,
        ctx: &Context<'_>,
        owner: Owner,
    ) -> Result<Vec<ProposalView>> {
        let state = ctx.data::<Arc<MultisigState>>()?;
        let confirmed_ids = state.confirmations.get(&owner).await?.unwrap_or_default();
        
        let mut proposals = Vec::new();
        for id in confirmed_ids {
            if let Some(proposal) = state.pending_proposals.get(&id).await? {
                proposals.push(proposal_to_view(proposal));
            } else if let Some(proposal) = state.executed_proposals.get(&id).await? {
                proposals.push(proposal_to_view(proposal));
            }
        }
        
        Ok(proposals)
    }
}

/// Convert internal Proposal to ProposalView for GraphQL
fn proposal_to_view(proposal: Proposal) -> ProposalView {
    let proposal_type_str = match &proposal.proposal_type {
        ProposalType::Transfer { to, value, .. } => {
            format!("Transfer {{ to: {:?}, value: {} }}", to, value)
        }
        ProposalType::AddOwner { owner } => {
            format!("AddOwner {{ owner: {:?} }}", owner)
        }
        ProposalType::RemoveOwner { owner } => {
            format!("RemoveOwner {{ owner: {:?} }}", owner)
        }
        ProposalType::ReplaceOwner { old_owner, new_owner } => {
            format!("ReplaceOwner {{ old_owner: {:?}, new_owner: {:?} }}", old_owner, new_owner)
        }
        ProposalType::ChangeThreshold { threshold } => {
            format!("ChangeThreshold {{ threshold: {} }}", threshold)
        }
    };

    ProposalView {
        id: proposal.id,
        proposal_type: proposal_type_str,
        proposer: proposal.proposer,
        confirmation_count: proposal.confirmation_count,
        executed: proposal.executed,
        created_at: proposal.created_at,
    }
}
