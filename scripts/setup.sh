#!/usr/bin/env bash
# AgentVault local setup.
#
# What this does:
#   1. Checks that Foundry is installed
#   2. Fetches pinned dependencies (forge-std, as a git submodule)
#   3. Builds the contracts
#   4. Runs the test suite
#
# It does NOT touch any blockchain, spend any money, or need admin rights.
#
# Run from the repository root:
#   bash scripts/setup.sh

set -euo pipefail

echo "==> Checking for Foundry..."
if ! command -v forge >/dev/null 2>&1; then
  echo "ERROR: 'forge' not found."
  echo "Install Foundry first:"
  echo "  curl -L https://foundry.paradigm.xyz | bash"
  echo "  # then reopen your terminal and run:"
  echo "  foundryup"
  exit 1
fi
forge --version

cd "$(dirname "$0")/../packages/contracts"

# Dependencies are tracked as git submodules and pinned by commit. This is
# idempotent and always checks out the pinned revision, which is why it is used
# instead of `forge install` — that would fetch the dependency's default branch
# and silently drift off the pin.
echo "==> Fetching pinned dependencies..."
git submodule update --init --recursive

echo "==> Building..."
forge build

echo "==> Testing..."
forge test -vv

echo ""
echo "Setup complete. Expected result: 7 passed, 0 failed."
