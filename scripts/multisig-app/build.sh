#!/bin/bash
# Copyright (c) 2025 PalmeraDAO
# SPDX-License-Identifier: MIT

# Build script for Linera Multisig Application

set -e

echo "=========================================="
echo "Building Linera Multisig Application"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if cargo is installed
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: cargo is not installed${NC}"
    exit 1
fi

echo ""
echo "Step 1: Running unit tests..."
echo "------------------------------------------"
if cargo test; then
    echo -e "${GREEN}✓ Tests passed${NC}"
else
    echo -e "${RED}✗ Tests failed${NC}"
    exit 1
fi

echo ""
echo "Step 2: Checking code formatting..."
echo "------------------------------------------"
if cargo fmt -- --check; then
    echo -e "${GREEN}✓ Code is properly formatted${NC}"
else
    echo -e "${YELLOW}⚠ Code formatting issues detected. Run 'cargo fmt' to fix${NC}"
fi

echo ""
echo "Step 3: Running clippy lints..."
echo "------------------------------------------"
if cargo clippy -- -D warnings; then
    echo -e "${GREEN}✓ No linting errors${NC}"
else
    echo -e "${YELLOW}⚠ Linting warnings detected${NC}"
fi

echo ""
echo "Step 4: Building library..."
echo "------------------------------------------"
if cargo build --release; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Build completed successfully!${NC}"
echo "=========================================="
echo ""
echo "Artifacts:"
echo "  - Library: target/release/liblinera_multisig.rlib"
echo "  - Contract: target/release/multisig_contract"
echo "  - Service: target/release/multisig_service"
