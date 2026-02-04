#!/usr/bin/env bash
# Linera Multisig - CLI Wrapper Script
#
# This script provides CLI access to the multisig contract state
# Used because GraphQL service is temporarily disabled (see docs/research/MULTISIG_GRAPHQL_SERVICE.md)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Default values (can be overridden via env vars or args)
CHAIN_ID="${CHAIN_ID:-}"
APPLICATION_ID="${APPLICATION_ID:-}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Linera Multisig - CLI Access Wrapper${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Function to query contract state
query_contract() {
    local chain_id="$1"
    local app_id="$2"

    echo -e "${BLUE}▸${NC} Querying contract state..."
    echo -e "   Chain ID: ${GREEN}$chain_id${NC}"
    echo -e "   Application ID: ${GREEN}$app_id${NC}"
    echo ""

    linera query-contract "$chain_id" "$app_id" 2>&1 || {
        echo -e "${RED}Error querying contract${NC}"
        echo "Make sure the application is created and IDs are correct"
        return 1
    }
}

# Function to read specific object
read_object() {
    local chain_id="$1"
    local app_id="$2"

    echo -e "${BLUE}▸${NC} Reading application object..."
    linera read-object "$chain_id" "$app_id" 2>&1 || {
        echo -e "${RED}Error reading object${NC}"
        return 1
    }
}

# Function to show chain information
show_chain_info() {
    local chain_id="$1"

    echo -e "${BLUE}▸${NC} Chain Information:"
    linera query-chain "$chain_id" 2>&1 || {
        echo -e "${RED}Error querying chain${NC}"
        return 1
    }
}

# Function to list applications
list_applications() {
    local chain_id="$1"

    echo -e "${BLUE}▸${NC} Applications on chain:"
    linera list-applications "$chain_id" 2>&1 || {
        echo -e "${RED}Error listing applications${NC}"
        return 1
    }
}

# Main script logic
case "${1:-help}" in
    query)
        if [ -z "$CHAIN_ID" ] || [ -z "$APPLICATION_ID" ]; then
            echo -e "${RED}Error:${NC} CHAIN_ID and APPLICATION_ID must be set"
            echo ""
            echo "Usage:"
            echo "  CHAIN_ID=<chain_id> APPLICATION_ID=<app_id> $0 query"
            echo ""
            echo "Or set as environment variables:"
            echo "  export CHAIN_ID=your_chain_id"
            echo "  export APPLICATION_ID=your_application_id"
            exit 1
        fi
        query_contract "$CHAIN_ID" "$APPLICATION_ID"
        ;;

    read)
        if [ -z "$CHAIN_ID" ] || [ -z "$APPLICATION_ID" ]; then
            echo -e "${RED}Error:${NC} CHAIN_ID and APPLICATION_ID must be set"
            echo ""
            echo "Usage:"
            echo "  CHAIN_ID=<chain_id> APPLICATION_ID=<app_id> $0 read"
            exit 1
        fi
        read_object "$CHAIN_ID" "$APPLICATION_ID"
        ;;

    chain)
        if [ -z "$CHAIN_ID" ]; then
            echo -e "${RED}Error:${NC} CHAIN_ID must be set"
            echo ""
            echo "Usage:"
            echo "  CHAIN_ID=<chain_id> $0 chain"
            exit 1
        fi
        show_chain_info "$CHAIN_ID"
        ;;

    list)
        if [ -z "$CHAIN_ID" ]; then
            echo -e "${RED}Error:${NC} CHAIN_ID must be set"
            echo ""
            echo "Usage:"
            echo "  CHAIN_ID=<chain_id> $0 list"
            exit 1
        fi
        list_applications "$CHAIN_ID"
        ;;

    help|--help|-h)
        echo "Linera Multisig - CLI Access Wrapper"
        echo ""
        echo "USAGE:"
        echo "  $0 <command> [options]"
        echo ""
        echo "COMMANDS:"
        echo "  query     Query contract state (requires CHAIN_ID and APPLICATION_ID)"
        echo "  read      Read application object (requires CHAIN_ID and APPLICATION_ID)"
        echo "  chain     Show chain information (requires CHAIN_ID)"
        echo "  list      List applications on chain (requires CHAIN_ID)"
        echo "  help      Show this help message"
        echo ""
        echo "ENVIRONMENT VARIABLES:"
        echo "  CHAIN_ID         Chain ID (64-character hex string)"
        echo "  APPLICATION_ID   Application ID (64-character hex string)"
        echo ""
        echo "EXAMPLES:"
        echo "  # Query contract state"
        echo "  CHAIN_ID=e93fc78f... APPLICATION_ID=a1b2c3d4... $0 query"
        echo ""
        echo "  # Show chain information"
        echo "  CHAIN_ID=e93fc78f... $0 chain"
        echo ""
        echo "NOTE: This is a temporary workaround until GraphQL service is restored."
        echo "      See docs/research/MULTISIG_GRAPHQL_SERVICE.md for details."
        ;;

    *)
        echo -e "${RED}Error:${NC} Unknown command '$1'"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✓${NC} Command completed"
