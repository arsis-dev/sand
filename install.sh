#!/bin/bash
# install.sh — Install sand into ~/.local/bin
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${HOME}/.local/bin"

mkdir -p "$BIN_DIR"

# Symlink the main script
ln -sf "${SCRIPT_DIR}/bin/sand" "${BIN_DIR}/sand"

echo "sand installed → ${BIN_DIR}/sand"
echo "Make sure ${BIN_DIR} is in your PATH."
