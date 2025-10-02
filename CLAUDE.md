# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository that manages configuration files and development environment setup for macOS and Linux systems. The repository includes configurations for terminal applications, editors, shell environments, and custom utility scripts.

## Key Components

### Setup and Installation

- **Main setup script**: `./setup` - Primary installation script that symlinks configurations and installs dependencies
- **XDG_CONFIG_HOME**: Must be set before running setup script
- **Work-specific config**: Creates `shell/.config/shell/work` from `shell/.config/shell/work.example` if it doesn't exist

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
  - Contains `.config/lazygit/`, `.config/gh-dash/`, `.config/gitmux/`, `.config/sesh/`

### Custom Scripts (`bin/`)

Utility scripts for development workflow:

- `ghdash`: Contextual GitHub Dashboard launcher (uses repo-specific configs)
- `gitmux_text`: Custom tmux git status integration
- `sesh_*`: Session management shortcuts
- `git_*`: Git workflow utilities
- Database utilities: `db_backup`, `db_restore`, `db_clean_backups`
- `sesh_monorepo_discover`: Discover git repos and create tmux sessions

## Common Commands

### Environment Setup

```bash
# Full setup (requires XDG_CONFIG_HOME set)
./setup

# Build custom CLI
cd alx && go build && cd ..

# Install custom CLI
ln -sf "$PWD/alx/alx" "$HOME/.local/bin/alx"
```

### Development Workflow

```bash
# Session management
tm                    # Interactive session switcher (sesh + fzf)
sesh_dotf            # Quick switch to dotfiles session
sesh_nuvos           # Quick switch to nuvos session

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

- **Theme**: Catppuccin Mocha with custom status modules
- **Plugin manager**: TPM (Tmux Plugin Manager)
- **Custom modules**: Located in `tmux/.config/tmux/modules/`
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
