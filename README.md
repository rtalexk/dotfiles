# Dotfiles

WIP for the eternal quest of dotfiles management.

Setup script is also WIP

![NeoVim](/assets/neovim.png)

## Manual macOS setup

Not managed by `setup`, these live in system preferences and have to be redone by hand on a new machine.

- **Keyboard → Key repeat rate**: all the way to `Fast`
- **Keyboard → Delay until repeat**: all the way to `Short`
- **Keyboard → Keyboard Shortcuts → Modifier Keys → Caps Lock key**: `Escape`

One keyboard setting has no UI. Holding a key opens the accent picker instead of
repeating until it is off:

```bash
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
```
