// Linera multisig application - SDK compilation and opcode 252 validation
// Tests whether linera-sdk 0.15.11 + Rust 1.87 generates memory.copy opcodes

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Operation {
    Init { owners: Vec<Vec<u8>>, threshold: usize },
    ProposeTransaction { amount: u64, recipient: Vec<u8> },
    Approve { transaction_id: u64 },
    Execute { transaction_id: u64 },
    AddOwner { owner: Vec<u8> },
    RemoveOwner { owner: Vec<u8> },
    ChangeThreshold { threshold: usize },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PendingTransaction {
    pub id: u64,
    pub proposer: Vec<u8>,
    pub amount: u64,
    pub recipient: Vec<u8>,
    pub approvals: Vec<Vec<u8>>,
    pub executed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct MultisigState {
    pub owners: Vec<Vec<u8>>,
    pub threshold: usize,
    pub pending_transactions: HashMap<u64, PendingTransaction>,
    pub transaction_count: u64,
}

impl MultisigState {
    pub fn init(&mut self, owners: Vec<Vec<u8>>, threshold: usize) -> Result<(), String> {
        if !self.owners.is_empty() {
            return Err("Already initialized".into());
        }
        if threshold == 0 || threshold > owners.len() {
            return Err("Invalid threshold".into());
        }
        self.owners = owners;
        self.threshold = threshold;
        Ok(())
    }

    pub fn propose(&mut self, proposer: Vec<u8>, amount: u64, recipient: Vec<u8>) -> Result<u64, String> {
        self.validate_owner(&proposer)?;
        let id = self.transaction_count;
        self.transaction_count += 1;
        let tx = PendingTransaction {
            id,
            proposer: proposer.clone(),
            amount,
            recipient,
            approvals: vec![proposer],
            executed: false,
        };
        self.pending_transactions.insert(id, tx);
        Ok(id)
    }

    pub fn approve(&mut self, approver: Vec<u8>, tx_id: u64) -> Result<(), String> {
        self.validate_owner(&approver)?;
        let tx = self.pending_transactions.get_mut(&tx_id)
            .ok_or("Transaction not found")?;
        if tx.executed {
            return Err("Already executed".into());
        }
        if !tx.approvals.contains(&approver) {
            tx.approvals.push(approver);
        }
        Ok(())
    }

    pub fn execute(&mut self, executor: Vec<u8>, tx_id: u64) -> Result<PendingTransaction, String> {
        self.validate_owner(&executor)?;
        let tx = self.pending_transactions.get_mut(&tx_id)
            .ok_or("Transaction not found")?;
        if tx.executed {
            return Err("Already executed".into());
        }
        if tx.approvals.len() < self.threshold {
            return Err(format!(
                "Insufficient approvals: {}/{}",
                tx.approvals.len(),
                self.threshold
            ));
        }
        tx.executed = true;
        Ok(tx.clone())
    }

    pub fn add_owner(&mut self, caller: &[u8], new_owner: Vec<u8>) -> Result<(), String> {
        self.validate_owner(caller)?;
        if self.owners.contains(&new_owner) {
            return Err("Owner already exists".into());
        }
        self.owners.push(new_owner);
        Ok(())
    }

    pub fn remove_owner(&mut self, caller: &[u8], owner: &[u8]) -> Result<(), String> {
        self.validate_owner(caller)?;
        if let Some(pos) = self.owners.iter().position(|o| o.as_slice() == owner) {
            self.owners.remove(pos);
            Ok(())
        } else {
            Err("Owner not found".into())
        }
    }

    fn validate_owner(&self, owner: &[u8]) -> Result<(), String> {
        if !self.owners.iter().any(|o| o.as_slice() == owner) {
            return Err("Not an owner".into());
        }
        Ok(())
    }
}

// Export function to force Wasm code generation
#[no_mangle]
pub extern "C" fn process_operation(op_ptr: *const u8, op_len: usize) -> i32 {
    let data = unsafe { std::slice::from_raw_parts(op_ptr, op_len) };
    let mut state = MultisigState::default();
    match serde_json::from_slice::<Operation>(data) {
        Ok(Operation::Init { owners, threshold }) => {
            match state.init(owners, threshold) {
                Ok(()) => 0,
                Err(_) => -1,
            }
        }
        Ok(Operation::ProposeTransaction { amount, recipient }) => {
            match state.propose(vec![1, 2, 3], amount, recipient) {
                Ok(_) => 0,
                Err(_) => -1,
            }
        }
        _ => -2,
    }
}
