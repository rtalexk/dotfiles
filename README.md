# Dotfiles

WIP for the eternal quest of dotfiles management.

Setup script is also WIP

![NeoVim](/assets/neovim.png)

## Manual macOS setup

Not managed by `setup`, these have to be redone by hand on a new machine.

- **Keyboard → Key repeat rate**: all the way to `Fast`
- **Keyboard → Delay until repeat**: all the way to `Short`
- **Keyboard → Keyboard Shortcuts → Modifier Keys → Caps Lock key**: `Escape`
- **`DOTFILES_PRIVATE_REPO`**: the clone URL of a private sibling repository
  holding the configuration that cannot be public. It is in no repository, so it
  is the one value that has to be looked up again. Set it in
  `shell/.config/shell/machine` (see `shell/.config/shell/machine.example`), which
  `setup` creates on its first run, so pass it on that run:
  `DOTFILES_PRIVATE_REPO=... ./setup`

One keyboard setting has no UI. Holding a key opens the accent picker instead of
repeating until it is off:

```bash
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
```
