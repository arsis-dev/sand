---
title: "feat: Simplified deployment via Homebrew tap + curl installer"
type: feat
date: 2026-02-18
---

# Simplified Deployment

## Overview

sand requires too many manual steps to install: clone, install.sh, PATH config, brew install dependencies. The goal is to provide two install paths:

1. **Homebrew tap** (primary): `brew install arsis-dev/tap/sand`
2. **Curl one-liner** (fallback): `curl -fsSL https://sand.arsis.dev/install.sh | bash`

## Problem Statement

Current install flow:

```
brew install zellij lazygit yazi fzf terminal-notifier   # 5 manual deps
git clone https://github.com/arsis-dev/sand.git          # clone
cd sand && ./install.sh                                   # symlink
# + ensure ~/.local/bin is in PATH
```

This is 4+ steps with potential failure points. Compare to the target:

```
brew install arsis-dev/tap/sand
```

## Technical Approach

### Core change: `SAND_LIBEXEC` path resolution

The main blocker is that `bin/sand` resolves paths relative to `$0`:

```bash
# bin/sand:24-25 (current)
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LAYOUT_DIR="${SAND_LAYOUT_DIR:-${SCRIPT_DIR}/../layouts}"
HELPER="${SCRIPT_DIR}/sand-workspace-helper"
```

Homebrew puts binaries in `bin/` (symlinked) and private files in `libexec/` (not symlinked). The relative path `../layouts` breaks.

**Solution**: Add a `SAND_LIBEXEC` env var. Homebrew's `write_env_script` sets it automatically. Dev mode falls back to the current `readlink` resolution.

### Dependency strategy

**Note**: `sand-synth` and `synth/` will move to a separate repository. The sand formula only covers the core workspace manager.

| Dependency | Homebrew declaration | Rationale |
|------------|---------------------|-----------|
| `zellij` | `:recommended` | Core multiplexer, most users want it |
| `python@3.13` | `:recommended` | Required for named workspaces (`sand-workspace-helper`) |
| `tmux` | `:optional` | Alternative backend |
| `terminal-notifier` | `:recommended` | Notifications |
| `lazygit` | not declared | TUI app, user choice |
| `fzf` | not declared | UX enhancement, not critical |

### Phase 1: Path resolution refactor

**`bin/sand`** (3 lines changed at top):

```bash
if [ -n "${SAND_LIBEXEC:-}" ]; then
    LAYOUT_DIR="${SAND_LAYOUT_DIR:-${SAND_LIBEXEC}/layouts}"
    HELPER="${SAND_LIBEXEC}/sand-workspace-helper"
    NOTIFY="${SAND_LIBEXEC}/notify/notify.sh"
else
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    LAYOUT_DIR="${SAND_LAYOUT_DIR:-${SCRIPT_DIR}/../layouts}"
    HELPER="${SCRIPT_DIR}/sand-workspace-helper"
fi
```

This change is backwards-compatible: without `SAND_LIBEXEC`, the current behavior is preserved.

**Note**: `bin/sand-synth` will move to its own repo and is not covered by this plan.

### Phase 2: Homebrew tap repository

Create `arsis-dev/homebrew-tap` on GitHub with:

```
homebrew-tap/
  Formula/
    sand.rb
  README.md
```

**`Formula/sand.rb`**:

```ruby
class Sand < Formula
  desc "Multi-backend workspace manager for developers (Zellij/tmux/Ghostty)"
  homepage "https://github.com/arsis-dev/sand"
  url "https://github.com/arsis-dev/sand/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER"
  license "MIT"

  depends_on :macos
  depends_on "zellij" => :recommended
  depends_on "tmux" => :optional
  depends_on "python@3.13" => :recommended
  depends_on "terminal-notifier" => :recommended

  def install
    libexec.install "bin/sand"
    libexec.install "bin/sand-workspace-helper"
    libexec.install "layouts"
    libexec.install "notify"

    (bin/"sand").write_env_script libexec/"sand", SAND_LIBEXEC: libexec
    (bin/"sand-workspace-helper").write_env_script libexec/"sand-workspace-helper", SAND_LIBEXEC: libexec
    (bin/"sand-notify").write_env_script libexec/"notify/notify.sh", SAND_LIBEXEC: libexec
  end

  def caveats
    <<~EOS
      Recommended TUI apps for panels:
        brew install lazygit yazi fzf btop

      Workspaces: ~/.config/sand/workspaces/
      Run 'sand workspace new' to create your first workspace.
    EOS
  end

  test do
    assert_match "sand", shell_output("#{bin}/sand --help 2>&1")
  end
end
```

### Phase 3: Git tag + SHA

- [ ] Tag the sand repo: `git tag v0.1.0 && git push origin v0.1.0`
- [ ] Download the tarball and compute SHA256: `curl -sL https://github.com/arsis-dev/sand/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256`
- [ ] Update `Formula/sand.rb` with the real SHA

### Phase 4: Curl installer

Replace `install.sh` with a robust installer that:

1. Detects if Homebrew is available and suggests `brew install` first
2. Falls back to downloading the release tarball to `~/.local/share/sand/`
3. Creates symlinks in `~/.local/bin/`
4. Checks PATH and suggests shell config changes
5. Wraps everything in `main()` to prevent partial execution on interrupted download

```bash
#!/bin/bash
# install.sh — Install sand workspace manager
# Usage: curl -fsSL https://raw.githubusercontent.com/arsis-dev/sand/main/install.sh | bash
set -euo pipefail

REPO="arsis-dev/sand"
INSTALL_DIR="${SAND_INSTALL_DIR:-${HOME}/.local/share/sand}"
BIN_DIR="${SAND_BIN_DIR:-${HOME}/.local/bin}"
VERSION="${SAND_VERSION:-latest}"

info()  { printf "\033[0;32m[sand]\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m[sand]\033[0m %s\n" "$1"; }
error() { printf "\033[0;31m[sand]\033[0m %s\n" "$1" >&2; exit 1; }

main() {
    [ "$(uname -s)" = "Darwin" ] || error "sand is macOS only"

    # Suggest Homebrew if available
    if command -v brew &>/dev/null; then
        info "Homebrew detected. Recommended install:"
        info "  brew install arsis-dev/tap/sand"
        printf "Continue with manual install anyway? [y/N] "
        read -r answer
        [ "$answer" = "y" ] || [ "$answer" = "Y" ] || exit 0
    fi

    if [ "$VERSION" = "latest" ]; then
        VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
            | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')
        [ -n "$VERSION" ] || error "Could not resolve latest version"
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

    mkdir -p "$BIN_DIR"
    for cmd in sand sand-workspace-helper; do
        ln -sf "${INSTALL_DIR}/bin/${cmd}" "${BIN_DIR}/${cmd}"
    done
    ln -sf "${INSTALL_DIR}/notify/notify.sh" "${BIN_DIR}/sand-notify"

    if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
        warn "${BIN_DIR} is not in your PATH"
        case "$(basename "$SHELL")" in
            zsh)  warn "Add to ~/.zshrc: export PATH=\"${BIN_DIR}:\$PATH\"" ;;
            bash) warn "Add to ~/.bashrc: export PATH=\"${BIN_DIR}:\$PATH\"" ;;
        esac
    fi

    info "sand v${VERSION} installed!"
    info "Run 'sand --help' to get started."
}

main "$@"
```

### Phase 5: Update README

Update the Getting Started section:

```markdown
## Getting Started

### Option A: Homebrew (recommended)

\`\`\`bash
brew install arsis-dev/tap/sand
\`\`\`

### Option B: Quick install

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/arsis-dev/sand/main/install.sh | bash
\`\`\`

### Option C: From source

\`\`\`bash
git clone https://github.com/arsis-dev/sand.git
cd sand && ./install.sh
\`\`\`
```

## Acceptance Criteria

- [x] `bin/sand` supports `SAND_LIBEXEC` env var for path resolution
- [x] Existing dev workflow (`./install.sh` symlink) still works unchanged
- [x] `arsis-dev/homebrew-tap` repo exists with `Formula/sand.rb`
- [x] `brew install arsis-dev/tap/sand` installs sand and its recommended deps
- [x] `sand`, `sand-workspace-helper`, `sand-notify` are all in PATH after brew install
- [x] `sand neverresume` works after Homebrew install (workspace TOML + layouts found)
- [ ] `curl -fsSL .../install.sh | bash` works on a clean machine with just Homebrew
- [x] README updated with the 3 install options
- [x] Git tag `v0.1.0` published

## Dependencies & Risks

- **First release tag**: sand has no version tags yet. Need to decide on v0.1.0 vs v1.0.0.
- **`readlink -f`**: macOS doesn't have GNU readlink by default. Current code already uses it (and it works via Homebrew coreutils or macOS 12.3+ `readlink`). Verify compatibility.
- **Formula testing**: Need to test `brew install --build-from-source` locally before publishing.
- **No CI yet**: Formula SHA updates are manual. Could add a GitHub Action later.

## References

- Current install: `install.sh:1-15`
- Path resolution: `bin/sand:24-25`
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [How to Create a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Python for Formula Authors](https://docs.brew.sh/Python-for-Formula-Authors)
