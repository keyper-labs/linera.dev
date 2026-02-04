# Async-GraphQL Downgrade Attempts - Why They Failed

## Executive Summary

**All attempts to downgrade async-graphql from 7.0.17 to 6.x at the project level FAILED.**

This is because `linera-sdk 0.15.11` has an **exact version dependency** (`=7.0.17`) that cannot be overridden using standard Cargo mechanisms.

---

## Attempt 1: `[patch.crates-io]` with Registry Version

### Cargo.toml Configuration
```toml
[patch.crates-io]
async-graphql = { version = "6.0.5" }
```

### Result
```
error: patch for `async-graphql` resolved to more than one candidate
Found versions: 6.0.5, 6.0.6, 6.0.7, 6.0.9, 6.0.10, 6.0.11
Update the patch definition to select only one package.
```

**Problem**: Patch syntax requires exact version with `=`.

---

## Attempt 2: `[patch.crates-io]` with Exact Version

### Cargo.toml Configuration
```toml
[patch.crates-io]
async-graphql = { version = "=6.0.11" }
```

### Result
```
error: patch for `async-graphql` points to the same source,
but patches must point to different sources
```

**Problem**: Patches must point to a DIFFERENT source (not crates.io).

---

## Attempt 3: `[patch.crates-io]` with Git Repository

### Cargo.toml Configuration
```toml
[patch.crates-io]
async-graphql = { git = "https://github.com/async-graphql/async-graphql", tag = "v6.0.11" }
async-graphql-derive = { git = "...", tag = "v6.0.11" }
async-graphql-parser = { git = "...", tag = "v6.0.11" }
async-graphql-value = { git = "...", tag = "v6.0.11" }
```

### Result
```
warning: Patch `async-graphql v6.0.11` was not used in the crate graph.
Check that the patched package version and available features are compatible
with the dependency requirements.

Compiling async-graphql-value v7.2.1
error[E0658]: `let` expressions in this position are unstable
```

**Problem**: `linera-sdk` has `async-graphql = "=7.0.17"` (EXACT version), which cannot be patched to a different major version.

---

## Attempt 4: `[patch.crates-io]` + Remove Project Dependency

### Cargo.toml Configuration
```toml
[dependencies]
# async-graphql = "7.0"  # REMOVED

[patch.crates-io]
async-graphql = { git = "...", tag = "v6.0.11" }
# ... all sub-packages
```

### Result
```
warning: Patch `async-graphql v6.0.11` was not used in the crate graph.
Compiling async-graphql-value v7.2.1
error[E0658]: `let` expressions in this position are unstable
```

**Problem**: Even removing our direct dependency doesn't help - `linera-sdk` still requires `=7.0.17`.

---

## Attempt 5: Force Update with `cargo update`

### Command
```bash
cargo update -p async-graphql --precise 6.0.11
```

### Result
```
error: failed to select a version for the requirement `async-graphql = "^7.0"`
candidate versions found which didn't match: 6.0.11
location searched: crates.io index
required by package `linera-multisig v0.1.0`
```

**Problem**: Our project also requires async-graphql 7.0.

---

## Attempt 6: `[replace]` with Git Repository

### Cargo.toml Configuration
```toml
[replace]
"async-graphql:7.0.17" = { git = "...", tag = "v6.0.11" }
"async-graphql-derive:7.0.17" = { git = "...", tag = "v6.0.11" }
"async-graphql-parser:7.2.1" = { git = "...", tag = "v6.0.11" }
"async-graphql-value:7.2.1" = { git = "...", tag = "v6.0.11" }
```

### Result
```
error: failed to get `async-graphql` as a dependency of package `linera-sdk v0.15.11`
no matching package for override `async-graphql@7.0.17` found
location searched: https://github.com/async-graphql/async-graphql?tag=v6.0.11
```

**Problem**: async-graphql 6.x has different crate structure than 7.x. The replace cannot find matching packages.

---

## Root Cause Analysis

### Why `[patch]` Failed

The `linera-sdk` has an **exact version pin**:
```toml
[dependencies]
async-graphql = "=7.0.17"  # Note the "=" sign
```

**Cargo patch behavior**:
- Patches only work if the version matches the patch definition
- `=7.0.17` means ONLY 7.0.17, not 6.x
- Patches to different major versions are ignored

### Why `[replace]` Failed

**async-graphql 6.x vs 7.x structural differences**:
```
6.x structure:
├── async-graphql-derive
├── async-graphql-parser
├── async-graphql-value
└── async-graphql

7.x structure:
├── async-graphql-derive (7.0.17)
├── async-graphql-parser (7.2.1)  ← Different version!
├── async-graphql-value (7.2.1)   ← Different version!
└── async-graphql (7.0.17)
```

The `[replace]` directive tries to find `async-graphql@7.0.17` in the 6.x codebase, which doesn't exist.

---

## What WOULD Work?

### 1. Fork linera-sdk (NOT RECOMMENDED)

```bash
# 1. Fork the SDK
git clone https://github.com/linera-io/linera-protocol.git

# 2. Edit linera-sdk/Cargo.toml
# Change: async-graphql = "=7.0.17"
# To:     async-graphql = "6.0"

# 3. Fix all API compatibility issues (major work)

# 4. Use our fork
[dependencies]
linera-sdk = { git = "https://github.com/PalmeraDAO/linera-protocol", branch = "no-graphql-7" }
```

**Problems**:
- ❌ Massive maintenance burden
- ❌ API incompatibilities between 6.x and 7.x
- ❌ Will diverge from official SDK
- ❌ May break when Linera network updates

### 2. Wait for Linera SDK Update (RECOMMENDED)

Monitor these issues:
- [Issue #4742](https://github.com/linera-io/linera-protocol/issues/4742) - Opcode 252 discussion
- [PR #4894](https://github.com/linera-io/linera-protocol/pull/4894) - Rust 1.86 compatibility attempt

### 3. Use Multi-Owner Chains Only (WORKAROUND)

Accept the limitations of native multi-owner chains:
- No threshold (1-of-N)
- No proposal/approval workflow
- Anyone can execute immediately

---

## Conclusion

**Downgrading async-graphql at the project level is IMPOSSIBLE** because:

1. **Exact version pin**: `linera-sdk` requires `=7.0.17`
2. **Cargo limitations**: `[patch]`/[replace]` cannot override exact version pins to different major versions
3. **API incompatibility**: 6.x and 7.x have different crate structures

**Only the Linera development team can fix this** by:
- Updating `linera-kywasmtime` to support opcode 252, OR
- Refactoring `linera-sdk` to use async-graphql 6.x, OR
- Providing an alternative query layer compatible with Rust 1.86

---

## Test Evidence

All attempts were tested on:
- **Date**: February 4, 2026
- **Rust versions**: 1.86.0, 1.92.0 (stable)
- **Cargo version**: Latest
- **linera-sdk**: 0.15.11
- **async-graphql target**: 6.0.11

Each attempt failed with the errors documented above.

---

**Last Updated**: February 4, 2026
**Status**: IMPOSSIBLE - Requires Linera SDK team action
