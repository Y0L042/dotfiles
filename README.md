# dotfiles

Windows dotfiles managed with [chezmoi](https://chezmoi.io): nushell, starship, zellij, nvim.

| Tool     | Target                                  |
|----------|-----------------------------------------|
| nushell  | `%APPDATA%\nushell\{config,env}.nu`     |
| starship | `~\.config\starship.toml`               |
| zellij   | `~\.config\zellij\config.kdl` (via `ZELLIJ_CONFIG_DIR` set in config.nu) |
| nvim     | `%LOCALAPPDATA%\nvim`                   |

Not tracked: nushell's `vendor/autoload/starship.nu` (regenerated on every startup by config.nu) and `history.txt`.

## New machine

```nu
winget install twpayne.chezmoi
chezmoi init --apply Y0L042/dotfiles
```

## Daily use

```nu
chezmoi edit --apply ~/.config/starship.toml   # edit source + apply
chezmoi re-add                                 # or: edited the live file? pull it back in
chezmoi add <new-file>                         # start tracking a file
chezmoi diff / chezmoi status                  # what would change
chezmoi cd                                     # opens nu in the source repo -> git add/commit/push
chezmoi update                                 # pull + apply on another machine
```
