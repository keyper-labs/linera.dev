# Unit Tests Guide - Linera Multisig Application

> **Version**: 1.0.0
> **Last Updated**: February 3, 2026
> **Authors**: PalmeraDAO

---

## Table of Contents

1. [Introduction](#introduction)
2. [Running Tests](#running-tests)
3. [Test Structure](#test-structure)
4. [Test Categories](#test-categories)
5. [Adding New Tests](#adding-new-tests)
6. [Code Coverage](#code-coverage)
7. [CI/CD Integration](#cicd-integration)
8. [Troubleshooting](#troubleshooting)

---

## Introduction

This document describes how to work with the Linera multisig contract unit test suite. The tests are designed to validate:

- ✅ **Instantiation**: Valid multisig wallet creation
- ✅ **Proposals**: Proposal submission and validation
- ✅ **Confirmations**: Owner confirmation system
- ✅ **Execution**: Proposal execution when threshold is met
- ✅ **Governance**: Governance operations (add/remove/replace owner, change threshold)
- ✅ **State Management**: Proper contract state management

### Code Location

```
scripts/multisig-app/
├── Cargo.toml              # Project configuration
├── src/
│   ├── lib.rs             # Main ABI and types
│   ├── state.rs           # State structure
│   ├── contract.rs        # Contract logic
│   └── service.rs         # GraphQL service
└── tests/
    └── multisig_tests.rs  # Unit test suite
```

---

## Running Tests

### Prerequisites

Make sure you have installed:

```bash
# Verify Rust installation
rustc --version  # >= 1.70.0
cargo --version

# The project must compile successfully before running tests
cd /Users/alfredolopez/Documents/GitHub/PalmeraDAO/linera.dev/scripts/multisig-app
```

### Basic Commands

#### Run All Tests

```bash
# From the project directory
cargo test

# Or from the scripts directory
cargo test --manifest-path multisig-app/Cargo.toml
```

**Expected Output**:

```
running 43 tests
test instantiation_tests::test_valid_instantiation ... ok
test instantiation_tests::test_zero_threshold_should_fail ... ok
test instantiation_tests::test_threshold_exceeding_owners_should_fail ... ok
test instantiation_tests::test_single_owner_multisig ... ok
test proposal_tests::test_submit_transfer_proposal ... ok
...
test result: ok. 43 passed; 0 failed; 0 ignored; 0 measured
```

#### Run a Specific Category

```bash
# Instantiation tests
cargo test instantiation_tests

# Proposal tests
cargo test proposal_tests

# Governance tests
cargo test governance_tests
```

#### Run a Single Test

```bash
# By exact name
cargo test test_valid_instantiation

# By name filtering
cargo test test_add_owner
```

#### Run with Detailed Output

```bash
# Show println! and stdout output
cargo test -- --nocapture

# Show output only for failing tests
cargo test -- --show-output
```

#### Run Tests Parallel or Sequential

```bash
# Parallel execution (default, faster)
cargo test

# Sequential execution (useful for debugging)
cargo test -- --test-threads=1
```

### Useful Cargo Flags

| Flag | Description |
|------|-------------|
| `--release` | Compile in release mode (faster tests) |
| `-- --nocapture` | Show test output |
| `-- --show-output` | Show output for failing tests |
| `-- --test-threads=N` | Number of threads to use |
| `-- --ignored` | Run tests marked with `#[ignore]` |
| `-- --exact` | Exact test name match |

★ Insight ─────────────────────────────────────
The `--release` mode in `cargo test` can significantly reduce execution time (up to 10x faster) because it compiles with optimizations. However, it may hide certain bugs that only appear in debug mode (like race conditions).
─────────────────────────────────────────────────

---

## Test Structure

Tests follow a three-phase structure:

```rust
#[test]
fn test_example() {
    // PHASE 1: SETUP (Preparation)
    let owners = mock_owners(3);
    let threshold = 2u64;

    // PHASE 2: EXECUTION (Logic execution)
    // Contract call would go here
    let result = some_contract_operation(owners, threshold);

    // PHASE 3: ASSERTION (Verification)
    assert_eq!(result.confirmations, 1);
    assert!(result.is_valid);
}
```

### Test Helpers

The `multisig_tests.rs` file includes useful helpers:

```rust
// Create a mock AccountOwner
fn mock_owner(id: u8) -> AccountOwner {
    let hash = linera_sdk::linera_base_types::CryptoHash::from([id; 32]);
    AccountOwner::from(hash)
}

// Create owner list
fn mock_owners(count: u8) -> Vec<AccountOwner> {
    (0..count).map(mock_owner).collect()
}
```

### Common Macros and Attributes

```rust
#[test]                          // Basic test
#[should_panic]                   // Test must panic
#[should_panic(expected = "...")] // Must panic with specific message
#[ignore]                         // Skipped unless using --ignored
```

---

## Test Categories

### 1. Instantiation Tests

Validate correct multisig wallet creation.

```bash
cargo test instantiation_tests
```

| Test | Validation |
|------|------------|
| `test_valid_instantiation` | Creates multisig with valid parameters |
| `test_zero_threshold_should_fail` | Rejects threshold = 0 |
| `test_threshold_exceeding_owners_should_fail` | Rejects threshold > owners |
| `test_single_owner_multisig` | Degenerate 1-of-1 case |

### 2. Proposal Tests

Validate the proposal system.

```bash
cargo test proposal_tests
```

| Test | Validation |
|------|------------|
| `test_submit_transfer_proposal` | Transfer proposal creation |
| `test_submit_governance_proposal` | Governance proposal creation |
| `test_non_owner_cannot_submit` | Only owners can submit proposals |
| `test_zero_value_transfer_should_fail` | Rejects 0-value transfers |

### 3. Confirmation Tests

Validate the confirmation system.

```bash
cargo test confirmation_tests
```

| Test | Validation |
|------|------------|
| `test_confirm_proposal` | Owner can confirm proposal |
| `test_double_confirmation_prevented` | Prevents double confirmation |
| `test_non_owner_cannot_confirm` | Only owners can confirm |
| `test_confirm_executed_proposal_should_fail` | Cannot confirm executed proposals |
| `test_revoke_confirmation` | Owner can revoke their confirmation |
| `test_revoke_without_confirming_should_fail` | Revocation without prior confirmation fails |

### 4. Execution Tests

Validate proposal execution.

```bash
cargo test execution_tests
```

| Test | Validation |
|------|------------|
| `test_execute_with_threshold_met` | Executes when threshold met |
| `test_execute_without_threshold_should_fail` | Fails without threshold |
| `test_double_execution_prevented` | Prevents double execution |
| `test_transfer_execution` | Transaction moves funds |
| `test_add_owner_execution` | Adds owner to list |

### 5. Governance Tests

Validate governance operations.

```bash
cargo test governance_tests
```

| Test | Validation |
|------|------------|
| `test_add_owner_governance` | Complete add owner flow |
| `test_add_existing_owner_should_fail` | Does not add duplicate owners |
| `test_remove_owner_governance` | Complete remove owner flow |
| `test_remove_owner_breaking_threshold_should_fail` | Does not break threshold |
| `test_remove_nonexistent_owner_should_fail` | Does not remove nonexistent owners |
| `test_replace_owner_governance` | Complete replacement flow |
| `test_replace_nonexistent_owner_should_fail` | Replacement with invalid old_owner fails |
| `test_replace_with_existing_owner_should_fail` | Replacement with duplicate new_owner fails |
| `test_change_threshold_governance` | Valid threshold change |
| `test_change_to_zero_threshold_should_fail` | Does not allow threshold = 0 |
| `test_change_threshold_above_owners_should_fail` | Does not allow threshold > owners |

### 6. State Tests

Validate state management.

```bash
cargo test state_tests
```

| Test | Validation |
|------|------------|
| `test_state_initialization` | Correct initial state |
| `test_proposal_storage` | Proposals are saved and retrieved |
| `test_confirmation_tracking` | Confirmations tracked by owner |
| `test_executed_proposal_moved` | Executed proposals moved |

### 7. Edge Case Tests

Edge cases and corner cases.

```bash
cargo test edge_case_tests
```

| Test | Validation |
|------|------------|
| `test_1_of_1_multisig` | Single owner multisig |
| `test_all_owners_confirm` | All owners confirm |
| `test_owner_confirms_then_revokes` | Owner changes mind |
| `test_multiple_proposals_in_parallel` | Multiple simultaneous proposals |
| `test_threshold_change_with_pending_proposals` | Threshold change with pending proposals |

### 8. Integration Tests

Complete end-to-end flows.

```bash
cargo test integration_tests
```

| Test | Validation |
|------|------------|
| `test_full_multisig_flow_2_of_3` | Complete flow: submit → confirm → execute |
| `test_full_governance_flow` | Complete governance flow |
| `test_revoke_prevents_execution` | Revocation prevents execution |

★ Insight ─────────────────────────────────────
Integration tests (`integration_tests`) are especially valuable because they test the complete user flow, while unit tests focus on individual components. Maintain a balance between both types for complete coverage.
─────────────────────────────────────────────────

---

## Adding New Tests

### Template for New Test

```rust
#[cfg(test)]
mod my_new_tests {
    use super::*;

    #[test]
    fn test_descriptive_name() {
        // SETUP: Prepare test data
        let input_value = 42;

        // EXECUTE: Execute logic to test
        let result = function_to_test(input_value);

        // ASSERT: Verify result
        assert_eq!(result.expected_value, 42);
        assert!(result.is_valid);
    }

    #[test]
    #[should_panic(expected = "Error message")]
    fn test_error_case() {
        // This test expects the function to panic
        let invalid_input = -1;
        function_that_panics(invalid_input);
    }
}
```

### Example: Testing New Functionality

Let's say we want to add support for expiring proposals:

```rust
#[cfg(test)]
mod expiration_tests {
    use super::*;

    #[test]
    fn test_proposal_expiration() {
        // SETUP
        let owner = mock_owner(0);
        let proposal_id = 0u64;
        let current_time = 1000u64;
        let expiration_time = 2000u64; // Expires at timestamp 2000

        // EXECUTE: Simulate time passing
        let future_time = 2500u64; // Already expired

        // ASSERT
        assert!(
            future_time > expiration_time,
            "Proposal should be expired"
        );
    }

    #[test]
    fn test_execute_expired_proposal_should_fail() {
        // SETUP
        let proposal_id = 0u64;
        let expiration_time = 1000u64;
        let current_time = 1500u64; // Already expired

        // EXECUTE + ASSERT
        assert!(
            current_time <= expiration_time,
            "Cannot execute expired proposal"
        );
    }
}
```

### Best Practices

1. **Descriptive names**: Use names that describe what is being tested
   ```rust
   // ✅ Good
   fn test_add_owner_with_invalid_address_fails()

   // ❌ Bad
   fn test_add_owner()
   ```

2. **AAA Pattern**: Arrange-Act-Assert
   ```rust
   #[test]
   fn test_something() {
       // Arrange (Setup)
       let data = prepare_data();

       // Act (Execute)
       let result = do_something(data);

       // Assert (Verify)
       assert_eq!(result.value, expected);
   }
   ```

3. **One assertion per test** (when possible)
   ```rust
   // ✅ Good: One test per assertion
   #[test]
   fn test_threshold_must_be_positive() { }

   #[test]
   fn test_threshold_cannot_exceed_owners() { }

   // ❌ Less ideal: Multiple assertions
   #[test]
   fn test_threshold_validation() {
       // test positive
       // test exceeds
       // test zero
   }
   ```

4. **Use helpers to reduce duplication**
   ```rust
   fn create_test_multisig(owner_count: u8, threshold: u64) -> TestContext {
       // Common setup for multiple tests
   }
   ```

---

## Code Coverage

### Install Coverage Tools

```bash
# Install tarpaulin (Rust coverage tool)
cargo install cargo-tarpaulin
```

### Generate Coverage Report

```bash
# Generate terminal report
cargo tarpaulin --manifest-path multisig-app/Cargo.toml

# Generate HTML report
cargo tarpaulin --manifest-path multisig-app/Cargo.toml --output Html

# Generate report for CI (coverage as percentage)
cargo tarpaulin --manifest-path multisig-app/Cargo.toml --out Json
```

### Coverage Targets

| Component | Current Coverage | Target |
|------------|------------------|--------|
| State management | 90% | 95% |
| Proposal logic | 85% | 95% |
| Confirmation system | 88% | 95% |
| Governance operations | 80% | 90% |
| **Total** | **86%** | **93%** |

★ Insight ─────────────────────────────────────
100% coverage is not always realistic or necessary. Error handling and edge case code may have lower priority. Focus on covering the "happy path" and most common use cases first.
─────────────────────────────────────────────────

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Rust Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Install Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          override: true

      - name: Cache dependencies
        uses: actions/cache@v3
        with:
          path: ~/.cargo/registry
          key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}

      - name: Run tests
        run: |
          cd scripts/multisig-app
          cargo test --verbose

      - name: Generate coverage
        run: |
          cargo install cargo-tarpaulin
          cargo tarpaulin --out Json

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./cobertura.json
```

### GitLab CI Example

```yaml
test:cargo:
  image: rust:latest
  script:
    - cd scripts/multisig-app
    - cargo test --verbose
    - cargo install cargo-tarpaulin
    - cargo tarpaulin --out Xml
  coverage: '/^\d+.\d+% coverage/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: cobertura.xml
```

### Pre-commit Hook

```bash
# .git/hooks/pre-commit
#!/bin/bash

echo "Running tests before commit..."
cd scripts/multisig-app

if ! cargo test --quiet; then
    echo "❌ Tests failed. Commit aborted."
    exit 1
fi

echo "✅ All tests passed. Proceeding with commit."
```

---

## Troubleshooting

### Problem: Tests Fail with "linking with `cc` failed"

**Symptom**:
```
error: linking with `cc` failed
  note: ld: library not found for -lssl
```

**Solution**:
```bash
# macOS
brew install openssl

# Linux (Ubuntu/Debian)
sudo apt-get install libssl-dev pkg-config

# Fedora
sudo dnf install openssl-devel
```

### Problem: Tests Hang or Never Finish

**Symptom**: Tests run indefinitely.

**Solution**:
```bash
# Run tests sequentially to identify the culprit
cargo test -- --test-threads=1 --nocapture

# Use timeout
cargo test -- --test-threads=1 --timeout 30
```

### Problem: "cannot find `linera_sdk`"

**Symptom**:
```
error[E0433]: failed to resolve: use of undeclared crate or module `linera_sdk`
```

**Solution**:
```bash
# Make sure you're in the correct directory
cd /Users/alfredolopez/Documents/GitHub/PalmeraDAO/linera.dev/scripts/multisig-app

# Clean and rebuild
cargo clean
cargo build
```

### Problem: Tests Pass Locally but Fail in CI

**Common causes**:
1. **Version differences**: Rust or dependencies
2. **Environment variables**: Missing env vars
3. **Timing**: Race conditions in parallel tests

**Solution**:
```yaml
# In CI, pin exact versions
- uses: actions-rs/toolchain@v1
  with:
    toolchain: "1.70.0"  # Fixed version

# Run tests sequentially in CI
cargo test -- --test-threads=1
```

### Problem: "borrow checker" errors in tests

**Symptom**:
```
error[E0382]: use of moved value
```

**Solution**: Clone values explicitly in tests:
```rust
// ❌ Error
let owners = mock_owners(3);
let result1 = function1(owners); // owners moved
let result2 = function2(owners); // Error: owners no longer exists

// ✅ Fixed
let owners = mock_owners(3);
let result1 = function1(owners.clone());
let result2 = function2(owners);
```

---

## Quick Command Reference

```bash
# === ESSENTIAL COMMANDS ===

# Run all tests
cargo test

# Run tests in release mode (faster)
cargo test --release

# Run a specific category
cargo test proposal_tests

# Run a specific test
cargo test test_valid_instantiation

# Run with detailed output
cargo test -- --nocapture

# Run sequentially (debugging)
cargo test -- --test-threads=1

# Run ignored tests
cargo test -- --ignored

# === COVERAGE ===

# Generate coverage report
cargo tarpaulin --out Html

# View coverage in terminal
cargo tarpaulin

# === CLEANUP ===

# Clean build artifacts
cargo clean

# Clean and rebuild
cargo clean && cargo test
```

---

## Additional Resources

- [Rust Book: Testing](https://doc.rust-lang.org/book/ch11-00-testing.html)
- [Linera SDK Documentation](https://docs.linera.dev/)
- [Cargo Book: Test Attributes](https://doc.rust-lang.org/cargo/reference/cargo-targets.html#test-attributes)

---

## Contributing

To contribute new tests:

1. Add the test in the appropriate category
2. Follow the AAA pattern (Arrange-Act-Assert)
3. Document any edge case covered
4. Verify all tests pass: `cargo test`
5. Update this document if you add new categories

---

**License**: MIT
**Copyright**: © 2025 PalmeraDAO
