# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Sand

Multi-backend workspace manager for developers. Launches pre-configured terminal sessions with split panes and TUI apps using Zellij (default), tmux, or Ghostty. Includes a notification sound system for Claude Code hooks and a sound synthesis engine.

## Commands

```bash
# Syntax check all source files
python3 -m py_compile synth/engine.py
python3 -m py_compile bin/sand-synth
python3 -m py_compile bin/sand-workspace-helper
bash -n bin/sand
bash -n notify/notify.sh

# Test workspace helper
bin/sand-workspace-helper catalog                    # List TUI apps
bin/sand-workspace-helper validate <file.toml>       # Validate a workspace
bin/sand-workspace-helper render <file.toml>         # Generate KDL output
bin/sand-workspace-helper render-tmux <file.toml>    # Generate tmux script

# Test sound synthesis
bin/sand-synth presets                               # List presets
bin/sand-synth generate zen-stop /tmp/test.aiff      # Generate a sound
bin/sand-synth play zen-stop                         # Generate + play
```

There is no test suite. Validation is manual: syntax checks + running commands above.

## Architecture

**`bin/sand`** (Bash) — Main entry point. Handles argument parsing, session management (create/restore/kill), nesting detection, backend selection. For named workspaces, it delegates to the Python helper for layout generation, then launches the multiplexer.

**`bin/sand-workspace-helper`** (Python) — Reads TOML workspace configs, generates KDL (Zellij) or tmux scripts. Also contains the TUI apps catalog (`APPS_CATALOG` dict), the interactive wizard, migration logic (old plain text → TOML), and validation. This is the largest file (~720 lines).

**`bin/sand-synth`** (Python) — CLI for sound generation. Reads presets from `synth/presets.json`, delegates rendering to `synth/engine.py`.

**`synth/engine.py`** — Audio synthesis: generates numpy int16 arrays from frequency/harmonic/envelope parameters, writes AIFF 16-bit mono manually via `struct` (no `aifc` module — removed in Python 3.13).

**`notify/notify.sh`** (Bash) — Manages notification sound packs. Syncs `.aiff` files to `~/Library/Sounds/` for macOS `terminal-notifier`. Called by Claude Code hooks via `sand-notify notify <type>`.

**`layouts/*.kdl`** — Static Zellij layout files for non-workspace sessions.

### Key data flow

```
sand <workspace> → detects .toml → sand-workspace-helper render → KDL → zellij
sand <workspace> --tmux → sand-workspace-helper render-tmux → bash script → tmux
```

### Config locations

- `~/.config/sand/workspaces/*.toml` — Workspace definitions
- `~/.config/sand/sounds/<pack>/{stop,question,tool}/` — Sound packs
- `~/.config/sand/notify.conf` — Active sound pack name

## Conventions

- All code comments and user-facing strings are in **English**
- Commit messages use **conventional commits** in English (`feat:`, `fix:`, `refactor:`)
- No `Co-Authored-By` footer in commits
- Python requires **3.11+** (uses `tomllib` from stdlib)
- Bash scripts use `set -euo pipefail`
- The workspace helper uses **relative tmux navigation** (`{left}`, `{top}`, `{start}`) instead of absolute pane indices, for compatibility with any `base-index` / `pane-base-index` setting
- When adding a new TUI app, add it to `APPS_CATALOG` in `bin/sand-workspace-helper` with all fields: `cmd`, `args`, `cat`, `brew`, `desc`, and optionally `install` for non-brew installs
