#!/usr/bin/env bash
# AgentVault local setup.
#
# What this does:
#   1. Checks that Foundry is installed
#   2. Installs forge-std (the Foundry standard test library)
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

echo "==> Installing forge-std..."
if [ ! -d "lib/forge-std" ]; then
  forge install foundry-rs/forge-std
else
  echo "    already present, skipping"
fi

echo "==> Building..."
forge build

echo "==> Testing..."
forge test -vv

echo ""
echo "Setup complete. Expected result: 7 passed, 0 failed."
