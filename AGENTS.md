# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository that manages configuration files and development environment setup for macOS and Linux systems. The repository includes configurations for terminal applications, editors, shell environments, and custom utility scripts.

## Key Components

### Setup and Installation

- **Main setup script**: `./setup` - Primary installation script that symlinks configurations and installs dependencies
- **XDG_CONFIG_HOME**: Must be set before running setup script
- **Work-specific config**: Creates `shell/.config/shell/work` from `shell/.config/shell/work.example` if it doesn't exist
- **Submodules**: Clone with `--recurse-submodules`, or let `./setup` run `git submodule update --init --recursive`. Two vendored themes are submodules: `terminal/.config/alacritty/themes` (alacritty-theme) and `tmux/.config/tmux/plugins/catppuccin/tmux` (pinned to v2.1.3). A plain clone leaves both directories empty and the tmux status modules fail to load.
- **demux**: Setup clones it to `$PROJECTS/demux` in the same bare-worktree layout as any other project and builds it with `go build`, version-stamped from `git describe`, symlinked into `~/.local/bin`. It is not installed from Homebrew, so the binary tracks the checkout.
- **Pre-existing config files**: Setup backs up `~/.zshrc` and `~/.tmux.conf` to `*.pre-dotfiles.bak` when they are regular files rather than symlinks, otherwise stow refuses to link over them. `~/.claude/settings.json` belongs to the private repo, which does its own backing up.
- **Destination directories**: Setup creates `~/.claude` before stowing. Stow links a directory whole when the target lacks it, which would redirect everything later written there into this repository.

### Private Configuration

The configuration that cannot be public (Claude Code settings, per-project agent instructions, helper scripts, and the `project.toml` and `.bare/info/exclude` files that live at project roots) is kept in a private sibling repository with its own setup script.

- **Clone URL**: `DOTFILES_PRIVATE_REPO`, resolved by `bin/private_repo_url` from the environment first, then from `shell/.config/shell/work`. The variable is commented out in `shell/.config/shell/work.example`, so a fresh machine passes it once: `DOTFILES_PRIVATE_REPO=... ./setup`
- **Location**: cloned to `private/` beside this worktree, at the bare-clone project root, so no worktree has to ignore it
- **Runs another repository's script**: `./setup` executes `../private/setup` when it is executable. A failure there is logged and the rest of setup continues
- **Unset or unreachable**: setup logs and skips the whole private phase, so the public configuration installs on its own. The clone is over SSH and setup provisions no key
- **Cloned once**: setup clones only when `../private/.git` is absent and never fetches, so pull that repository by hand to pick up config added on another machine
- **Owns `~/.claude`**: `settings.json` and `CLAUDE.md` both come from there. `settings.json` carries `autoMode.environment`, which describes a private employer system, so it cannot live in this repository. Setup warns when the file is absent after the private phase, because Claude Code otherwise starts with no hooks and no `autoMode` policy and says nothing about it
- **`omc-patch`**: the private repo also carries the `omc-patch` package, which builds a patched oh-my-claudecode tree into `~/.local/share/omc-patched` from pinned upstreams and a frozen merge manifest. The `claude` shell function in `shell/.config/shell/user_config` points `--plugin-dir` at it when it exists

### Custom CLI Tool (`alx/`)

- **Language**: Go (requires Go 1.22.1+)
- **Build**: `cd alx && go build`
- **Install**: `ln -sf "$PWD/alx/alx" "$HOME/.local/bin/alx"`
- **Purpose**: Personal productivity commands built with Cobra CLI framework
- **Help**: `alx help`

### Configuration Structure

Configurations are organized by tool category and symlinked to `$XDG_CONFIG_HOME/`:

- **nvim/**: Neovim configuration using Lazy.nvim package manager
  - Contains `.config/nvim/` with modular Lua configuration
- **tmux/**: Tmux configuration with Catppuccin theme and TPM plugins
  - Contains `.config/tmux/` and `.tmux.conf`
- **shell/**: Shell environment and aliases
  - Contains `.config/shell/` for aliases and user config, plus `.zshrc`
- **terminal/**: Terminal emulator configurations
  - Contains `.config/alacritty/`, `.config/ghostty/`, `.config/zellij/`
- **git-tools/**: Git workflow and session management tools
  - Contains `.config/lazygit/`, `.config/gh-dash/`, and `.config/gitmux/`

### Custom Scripts (`bin/`)

Utility scripts for development workflow:

- `ghdash`: Contextual GitHub Dashboard launcher (uses repo-specific configs)
- `gitmux_text`: Custom tmux git status integration
- `git_*`: Git workflow utilities
- Database utilities: `db_backup`, `db_restore`, `db_clean_backups`

## Common Commands

### Environment Setup

```bash
# Clone (submodules carry the alacritty and catppuccin themes)
git clone --recurse-submodules git@github.com:rtalexk/dotfiles.git

# Full setup (requires XDG_CONFIG_HOME set)
./setup

# Build custom CLI
cd alx && go build && cd ..

# Install custom CLI
ln -sf "$PWD/alx/alx" "$HOME/.local/bin/alx"
```

### Development Workflow

```bash
# project.toml lives at the bare-clone project root (one level above the repo),
# so it is never cloned and must be created per machine. Without it the tmux
# session name falls back to the directory name.
alx worktree project init     # then set `alias`, e.g. dotf

# alx worktree main connects to the worktree holding the default branch,
# resolved from project.toml `default_branch`, then origin/HEAD, then "main".
# Set default_branch only when origin/HEAD is unset or points elsewhere.

# Session management, demux is the primary session flow
demux                         # Open the session manager
demux --compact               # Open the compact session manager
demux session connect NAME    # Connect to a named session
alx worktree main             # Connect to the current project's main session

# Git shortcuts (from shell/.config/shell/aliases/git)
gcwip                # Quick WIP commit (git add . && git commit --no-verify -m 'wip')
gbdm                 # Delete merged branches (excludes main/master/dev)
difon                # Show changed files vs origin/main
difo                 # Show diff vs origin/main

# Editor shortcuts
nv                   # Launch neovim
nvz                  # Launch alternate neovim config (nvim_lz)
```

### Tmux Integration

- **Prefix**: Default tmux prefix
- **Lazygit**: `prefix + g` opens lazygit in current directory
- **GitHub Dashboard**: `prefix + G` opens gh-dash
- **Session switching**: `Alt + l` switches to previous session
- **Reload config**: `prefix + r`

## Architecture Notes

### Neovim Configuration

- **Plugin manager**: Lazy.nvim
- **Structure**: Modular configuration in `nvim/.config/nvim/lua/`
- **Plugins**: Organized by category (code, editor, lsp, etc.)
- **Environment variable**: Sets `WITHIN_EDITOR=1` for CLI integration

### Tmux Setup

- **Theme**: Catppuccin Mocha with custom status modules. The theme is vendored as a submodule and loaded with `run '~/.config/tmux/plugins/catppuccin/tmux/catppuccin.tmux'`, not as a TPM plugin, so the version stays pinned
- **Plugin manager**: TPM (Tmux Plugin Manager), for every plugin except Catppuccin
- **Custom modules**: Located in `tmux/.config/tmux/modules/`. Each sources `utils/status_module.conf` from the Catppuccin submodule, so module paths must track the submodule, not `~/.tmux/plugins/`
- **Status line**: Shows git status, PR count, battery, time
- **Vim integration**: Uses vim-tmux-navigator for pane switching

### Shell Environment

- **Framework**: Oh My Zsh with custom configurations
- **Aliases**: Organized by category in `shell/.config/shell/aliases/`
- **Work config**: Separate work-specific settings in `shell/.config/shell/work`

### Platform-Specific Dependencies

**macOS (Homebrew)**:

- Core: `nvim`, `tmux`, `rg`, `fzf`, `zoxide`
- Terminal: `alacritty`
- Git tools: `lazygit`, `gh`
- Fonts: `font-hack-nerd-font`

**Linux (apt)**:

- `build-essential`, `ripgrep`, `tmux`, `fd-find`
- Node.js via nvm, Ruby via rvm

## Testing and Linting

No automated test suite. Manual testing involves:

1. Running `./setup` in a clean environment
2. Verifying symlinks are created correctly
3. Testing tmux sessions and key bindings
4. Confirming neovim loads without errors

## Code Style

- Do not add comment lines for functions or variables unless necessary.
  - If the comment is quite similar to the function/variable name, it is redundant.
