#!/bin/bash
# install.sh — Install sand workspace manager
# Usage:
#   From source:  ./install.sh
#   Remote:       curl -fsSL https://raw.githubusercontent.com/arsis-dev/sand/main/install.sh | bash
set -euo pipefail

REPO="arsis-dev/sand"
INSTALL_DIR="${SAND_INSTALL_DIR:-${HOME}/.local/share/sand}"
BIN_DIR="${SAND_BIN_DIR:-${HOME}/.local/bin}"
VERSION="${SAND_VERSION:-}"

info()  { printf "\033[0;32m[sand]\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m[sand]\033[0m %s\n" "$1"; }
error() { printf "\033[0;31m[sand]\033[0m %s\n" "$1" >&2; exit 1; }

install_from_source() {
    local src_dir="$1"
    info "Installing from source: ${src_dir}"

    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cp -R "$src_dir/bin" "$INSTALL_DIR/"
    cp -R "$src_dir/layouts" "$INSTALL_DIR/"
    cp -R "$src_dir/notify" "$INSTALL_DIR/"
    [ -d "$src_dir/synth" ] && cp -R "$src_dir/synth" "$INSTALL_DIR/"

    create_symlinks
}

install_from_remote() {
    if [ -z "$VERSION" ]; then
        VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
            | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/' || true)
        [ -n "$VERSION" ] || error "Could not resolve latest version. Set SAND_VERSION manually."
    fi
    info "Installing sand v${VERSION}..."

    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    curl -fsSL "https://github.com/${REPO}/archive/refs/tags/v${VERSION}.tar.gz" \
        | tar xz -C "$tmpdir" --strip-components=1

    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cp -R "$tmpdir/bin" "$INSTALL_DIR/"
    cp -R "$tmpdir/layouts" "$INSTALL_DIR/"
    cp -R "$tmpdir/notify" "$INSTALL_DIR/"
    [ -d "$tmpdir/synth" ] && cp -R "$tmpdir/synth" "$INSTALL_DIR/"

    create_symlinks
}

create_symlinks() {
    mkdir -p "$BIN_DIR"
    for cmd in sand sand-workspace-helper; do
        ln -sf "${INSTALL_DIR}/bin/${cmd}" "${BIN_DIR}/${cmd}"
    done
    ln -sf "${INSTALL_DIR}/notify/notify.sh" "${BIN_DIR}/sand-notify"

    # sand-synth (optional, may not exist in future versions)
    [ -f "${INSTALL_DIR}/bin/sand-synth" ] && \
        ln -sf "${INSTALL_DIR}/bin/sand-synth" "${BIN_DIR}/sand-synth"

    check_path
    info "sand installed to ${INSTALL_DIR}"
    info "Run 'sand --help' to get started."
}

check_path() {
    if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
        warn "${BIN_DIR} is not in your PATH"
        case "$(basename "${SHELL:-/bin/zsh}")" in
            zsh)  warn "Add to ~/.zshrc:  export PATH=\"${BIN_DIR}:\$PATH\"" ;;
            bash) warn "Add to ~/.bashrc: export PATH=\"${BIN_DIR}:\$PATH\"" ;;
            fish) warn "Run: fish_add_path ${BIN_DIR}" ;;
        esac
    fi
}

main() {
    [ "$(uname -s)" = "Darwin" ] || error "sand is macOS only"

    # Detect if running from a cloned repo (local install)
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

    if [ -f "$script_dir/bin/sand" ] && [ -d "$script_dir/layouts" ]; then
        # Local source install
        install_from_source "$script_dir"
    else
        # Remote install (curl | bash)
        if command -v brew &>/dev/null; then
            info "Homebrew detected. Recommended:"
            info "  brew install arsis-dev/tap/sand"
            printf "Continue with manual install? [y/N] "
            read -r answer </dev/tty
            [ "$answer" = "y" ] || [ "$answer" = "Y" ] || exit 0
        fi
        install_from_remote
    fi
}

main "$@"
