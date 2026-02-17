#!/bin/bash
# install.sh — Installe sand dans ~/.local/bin
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${HOME}/.local/bin"

mkdir -p "$BIN_DIR"

# Symlink du script principal
ln -sf "${SCRIPT_DIR}/bin/sand" "${BIN_DIR}/sand"

echo "sand installé → ${BIN_DIR}/sand"
echo "Vérifie que ${BIN_DIR} est dans ton PATH."
