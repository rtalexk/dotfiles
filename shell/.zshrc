# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

export XDG_CONFIG_HOME="$HOME/.config"

# Prompt theme
source $XDG_CONFIG_HOME/oh_my_zsh/init
# source $XDG_CONFIG_HOME/oh_my_posh/init

# User configuration
source $XDG_CONFIG_HOME/shell/user_config

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# See `:help modeline`
# vim: ts=4 sts=4 sw=4 et

# pnpm
export PNPM_HOME="/Users/art/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Added by Antigravity
export PATH="/Users/rtalex/.antigravity/antigravity/bin:$PATH"
