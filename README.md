# dotfiles

Windows dotfiles managed with [chezmoi](https://chezmoi.io): nushell, starship, zellij and nvim, plus scripts that install the dev tools.

## Install

```powershell
winget install twpayne.chezmoi
chezmoi init Y0L042/dotfiles
```

This only clones the repo. Next, optionally install the tools (see [Bootstrap](#bootstrap)), then run `chezmoi apply` to put the configs in place.

## Managed configs

| Tool     | Target |
|----------|--------|
| nushell  | `%APPDATA%\nushell\config.nu`, `env.nu` |
| starship | `~\.config\starship.toml` |
| zellij   | `~\.config\zellij\config.kdl` (found via `ZELLIJ_CONFIG_DIR`, set in config.nu) |
| nvim     | `%LOCALAPPDATA%\nvim` |

Not tracked: nushell's `history.txt` and `vendor/autoload/starship.nu` (config.nu regenerates it on every start).

## Bootstrap

Optional and manual: `chezmoi apply` never runs these. There are two scripts, one per step. Run them from a normal (non-admin) PowerShell:

```powershell
$b = "$(chezmoi source-path)\bootstrap"
powershell -ExecutionPolicy Bypass -File $b\install-cli.ps1 -DryRun   # report only
powershell -ExecutionPolicy Bypass -File $b\install-cli.ps1           # step 1: CLI tools
powershell -ExecutionPolicy Bypass -File $b\install-gui.ps1           # step 2: GUI apps
chezmoi apply                                                         # step 3: configs
```

- Anything already installed is skipped, however it was installed: on PATH, through winget, or through scoop.
- Nothing is upgraded or downgraded. Upgrade with `winget upgrade --all` and `scoop update *`.
- `install-gui.ps1 -ApplyVsConfig` adds any missing workloads from `vs2026.vsconfig` to an existing VS 2026 install. It never removes any.

### Tools, in install order

`bootstrap/packages.psd1` is the source of truth. Keep this table in the same order.

| # | Tool | Source | Package ID | Purpose |
|---|------|--------|------------|---------|
| | **Step 1: `install-cli.ps1`** | | | |
| 1 | git | winget | `Git.Git` | Version control. First, because Scoop and vcpkg need it |
| 2 | python | winget | `Python.Python.3.13` | Python 3.13 runtime |
| 3 | node | winget | `OpenJS.NodeJS.LTS` | Node.js LTS + npm |
| 4 | rustup | winget | `Rustlang.Rustup` | Rust toolchain manager. Runs `rustup default stable` if no toolchain is installed |
| 5 | .NET SDK | winget | `Microsoft.DotNet.SDK.10` | .NET 10 SDK |
| 6 | LLVM | winget | `LLVM.LLVM` | clang, clangd, clang-format |
| 7 | nushell | winget | `Nushell.Nushell` | Shell |
| 8 | zellij | winget | `Zellij.Zellij` | Terminal multiplexer |
| 9 | Scoop | special | `get.scoop.sh` | Package manager for rows 10-19. Only installed if one of them is missing |
| 10 | ripgrep | scoop | `ripgrep` | Fast grep |
| 11 | fzf | scoop | `fzf` | Fuzzy finder |
| 12 | zoxide | scoop | `zoxide` | Smarter cd |
| 13 | starship | scoop | `starship` | Shell prompt |
| 14 | neovim | scoop | `neovim` | Editor |
| 15 | cmake | scoop | `cmake` | C/C++ build system generator |
| 16 | gh | scoop | `gh` | GitHub CLI |
| 17 | uv | scoop | `uv` | Python package/project manager |
| 18 | direnv | scoop | `direnv` | Per-directory env vars |
| 19 | chezmoi | scoop | `chezmoi` | Dotfiles manager. Skipped if already installed in [Install](#install) |
| 20 | vcpkg | special | `microsoft/vcpkg` (git clone) | C++ library manager. Cloned to `C:\Projects\_Tools\vcpkg`, sets `VCPKG_ROOT` |
| | **Step 2: `install-gui.ps1`** | | | |
| 21 | VS Code | winget | `Microsoft.VisualStudioCode` | Code editor |
| 22 | Notepad++ | winget | `Notepad++.Notepad++` | Text editor |
| 23 | Visual Studio 2026 | winget | `Microsoft.VisualStudio.Community` | IDE + MSVC, with the workloads from `vs2026.vsconfig`: core editor, .NET desktop, C++ desktop, C++ games, VS extension development |

Each scoop tool also checks for a winget install before installing, so a tool installed through winget (e.g. cmake) isn't installed a second time.

## Daily use

```powershell
chezmoi edit --apply <file>   # edit the source and apply it
chezmoi re-add                # edited a live file instead? pull the change back in
chezmoi add <file>            # start tracking a new file
chezmoi diff                  # preview what apply would change
chezmoi cd                    # open nu in the repo, then git add/commit/push
chezmoi update                # on another machine: pull + apply
```
