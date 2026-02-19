# Sand

Multi-backend workspace manager for developers. Sand launches pre-configured terminal sessions with split panes, TUI apps, and project-aware layouts using Zellij, tmux, or Ghostty.

Inspired by [Daniel Avila](https://x.com/dani_avila7)'s **SAND** mnemonic (**S**plit, **A**cross, **N**avigate, **D**estroy) for Ghostty panel management with Claude Code — [read his article](https://x.com/dani_avila7/status/2023151176758268349).

## Key Features

- **Named workspaces** with TOML config — define tabs, layouts, and panel apps per project
- **Multi-backend** — Zellij (default), tmux (fallback), Ghostty tabs
- **Layout presets** — default, wide, solo, monitoring
- **17 TUI apps catalog** — lazygit, yazi, btop, lazydocker, k9s, and more
- **Interactive wizard** — `sand workspace new` with fzf support
- **Auto sub-project detection** — parent directory with multiple git repos opens a multi-tab session
- **Notification sounds** — macOS notifications with custom sound packs when Claude Code stops or asks a question
## Tech Stack

- **Shell**: Bash (main script)
- **Python**: 3.11+ (workspace helper)
- **Multiplexers**: Zellij, tmux
- **Layout format**: KDL (Zellij), tmux commands
- **Config format**: TOML (workspaces)
- **Platform**: macOS (notifications use `terminal-notifier`)

## Prerequisites

- **Zellij** or **tmux** (at least one)
- **Python 3.11+** (for workspace helper)
- **lazygit** and **yazi** (for default layout panels)
- **fzf** (optional, enhances selection UIs)
- **terminal-notifier** (optional, for macOS notifications)

If installing via Homebrew, Zellij and terminal-notifier are installed automatically. For manual install:

```bash
brew install zellij lazygit yazi fzf terminal-notifier
```

## Getting Started

### Option A: Homebrew (recommended)

```bash
brew install arsis-dev/tap/sand
```

This installs sand with Zellij and terminal-notifier as recommended dependencies.

### Option B: Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/arsis-dev/sand/main/install.sh | bash
```

### Option C: From source

```bash
git clone https://github.com/arsis-dev/sand.git
cd sand
./install.sh
```

All options install to `~/.local/bin/`. Make sure it's in your `PATH`.

### Launch a Session

```bash
# In any project directory
sand

# In a specific directory
sand ~/Dev/myproject

# Solo mode (single terminal, no side panels)
sand --solo
```

### 3. Create a Workspace

```bash
# Interactive wizard
sand workspace new

# Or write TOML manually
$EDITOR ~/.config/sand/workspaces/myproject.toml
```

Then launch it:

```bash
sand myproject
```

## Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `sand` | New session in the current directory |
| `sand <dir>` | New session in a specific directory |
| `sand <workspace>` | Launch a named workspace |
| `sand --solo` | Single terminal pane |
| `sand --restore` / `-r` | Reattach last session (fzf selector) |
| `sand --attach` / `-a` | Reattach current project's session |
| `sand --list` / `-l` | List active sessions |
| `sand --kill` / `-k` | Close a session (fzf selector) |
| `sand --kill-all` / `-K` | Close all sessions |
| `sand --keys` | Zellij shortcuts cheat sheet |
| `sand --tips` | Launch with a cheat sheet pane |
| `sand --tmux` | Use tmux instead of Zellij |
| `sand --open dir1 dir2` | Multiple projects in Zellij tabs |
| `sand --open --ghostty dir1 dir2` | Multiple projects in Ghostty tabs |

### Workspace Management

| Command | Description |
|---------|-------------|
| `sand workspace new` | Interactive workspace creation wizard |
| `sand workspace list` | List all workspaces |
| `sand workspace show <name>` | Display workspace config |
| `sand workspace edit <name>` | Open TOML in `$EDITOR` |
| `sand workspace delete <name>` | Delete a workspace |
| `sand workspace migrate` | Migrate old plain text files to TOML |
| `sand workspace catalog` | List available TUI apps with install status |

### Notification Sounds

| Command | Description |
|---------|-------------|
| `sand-notify use <pack>` | Activate a sound pack |
| `sand-notify current` | Show active pack |
| `sand-notify packs` | List available packs |
| `sand-notify play [pack]` | Preview all sounds in a pack |
| `sand-notify test [stop\|question]` | Test a notification |
| `sand-notify add <pack> <type> <file>` | Add a sound to a pack |

## Architecture

```
sand/
├── bin/
│   ├── sand                    # Main entry point (Bash)
│   └── sand-workspace-helper   # TOML parsing, KDL/tmux generation, wizard (Python)
├── layouts/
│   ├── sand.kdl                # Default Zellij layout (terminal 60% + panels 40%)
│   └── sand-solo.kdl           # Solo layout (single terminal)
├── notify/
│   ├── notify.sh               # Notification sound pack manager
│   └── Sand.app/               # Stub macOS app for notification identity
├── docs/
│   └── plans/                  # Implementation plans
└── install.sh                  # Installer (source or remote)
```

### How It Works

```
sand myproject
  │
  ├─ Detects ~/.config/sand/workspaces/myproject.toml
  │
  ├─ Calls sand-workspace-helper render myproject.toml
  │   └─ Python reads TOML → generates KDL layout on stdout
  │
  └─ Launches: zellij --session myproject --new-session-with-layout <generated.kdl>
```

With `--tmux`:

```
sand myproject --tmux
  │
  ├─ Calls sand-workspace-helper render-tmux myproject.toml --session myproject
  │   └─ Python reads TOML → generates bash script with tmux commands
  │
  └─ Executes the generated tmux script
```

### Workspace TOML Format

Workspaces are stored as `.toml` files in `~/.config/sand/workspaces/`:

```toml
[workspace]
name = "diderot"
description = "Client Diderot — netcampus + dec"
root = "~/Dev/clients/diderot"     # optional, base for relative paths

[[tabs]]
name = "netcampus"
dir = "netcampus"                   # relative to root
layout = "default"                  # default, wide, solo, monitoring

[[tabs.panels]]
app = "lazygit"

[[tabs.panels]]
app = "yazi"

[[tabs]]
name = "dec"
dir = "dec"
# panels omitted → uses layout defaults (lazygit + yazi)
```

Custom commands are also supported:

```toml
[[tabs.panels]]
command = "docker compose logs -f"
```

### Layout Presets

```
"default"                             "wide"
┌───────────────┬──────────┐          ┌──────────────────────────┐
│               │ panel-1  │          │        terminal          │
│   terminal    │          │          │                          │
│   (60%)       ├──────────┤          ├─────────┬────────┬───────┤
│               │ panel-2  │          │ panel-1 │ panel-2│panel-3│
├───────┬───────┤          │          └─────────┴────────┴───────┘
│term-2 │term-3 │          │
└───────┴───────┴──────────┘

"solo"                                "monitoring"
┌──────────────────────────┐          ┌───────────────┬──────────┐
│                          │          │               │ panel-1  │
│         terminal         │          │   terminal    ├──────────┤
│                          │          │   (60%)       │ panel-2  │
│                          │          │               ├──────────┤
└──────────────────────────┘          │               │ panel-3  │
                                      └───────────────┴──────────┘
```

### Notification Sound Flow

```
Claude Code hook fires
  → sand-notify notify stop
    → picks random sound from active pack
    → terminal-notifier shows macOS notification with sound
```

Sound packs live in `~/.config/sand/sounds/<pack>/{stop,question,tool}/`. Files are synced to `~/Library/Sounds/` so macOS notifications can play them.

Sound packs can be generated with [sand-synth](https://github.com/arsis-dev/sand-synth) (separate project).

## Config Files

All sand configuration lives under `~/.config/sand/`:

| Path | Purpose |
|------|---------|
| `~/.config/sand/workspaces/*.toml` | Workspace definitions |
| `~/.config/sand/sounds/<pack>/` | Notification sound packs |
| `~/.config/sand/notify.conf` | Active sound pack name |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SAND_LAYOUT_DIR` | Custom layouts directory | `<sand-dir>/layouts` |
| `SAND_WORKSPACES_DIR` | Custom workspaces directory | `~/.config/sand/workspaces` |
| `EDITOR` | Editor for `sand workspace edit` | `vi` |

## License

MIT
