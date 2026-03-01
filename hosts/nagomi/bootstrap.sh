#!/usr/bin/env bash

# This script performs the initial switch to the nagomi NixOS configuration
# because flakes are experimental and might not be enabled on a fresh install.

set -e

# Ensure we are in the right directory
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd "$SCRIPT_DIR"

echo "Starting initial NixOS switch to 'nagomi'..."

# We use --extra-experimental-features to enable flakes for this first run.
# After this succeeds, the nagomi configuration will enable them permanently.
sudo nixos-rebuild switch --flake .#nagomi \
  --extra-experimental-features "nix-command flakes"

echo "Successfully switched to nagomi configuration!"
echo "You can now use the 'rebuild' alias for future updates."
