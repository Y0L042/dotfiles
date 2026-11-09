# dotfiles

Windows dotfiles managed with [chezmoi](https://chezmoi.io): nushell, starship, zellij, nvim.

| Tool     | Target                                  |
|----------|-----------------------------------------|
| nushell  | `%APPDATA%\nushell\{config,env}.nu`     |
| starship | `~\.config\starship.toml`               |
| zellij   | `~\.config\zellij\config.kdl` (via `ZELLIJ_CONFIG_DIR` set in config.nu) |
| nvim     | `%LOCALAPPDATA%\nvim`                   |

Not tracked: nushell's `vendor/autoload/starship.nu` (regenerated on every startup by config.nu) and `history.txt`.

## Bootstrap a machine

Installing tools is a **manual** step, separate from `chezmoi apply`, and split into two scripts in `bootstrap/` (the folder is in `.chezmoiignore`, so it is never copied into `~`).
Both scripts skip anything already installed, however it was installed (on PATH, known to winget, or known to scoop), and never upgrade or downgrade. Use `-DryRun` to only see the report.

`bootstrap/packages.psd1` is the source of truth. When you add a tool there, add it to the tables below too, in the same order.

### Install order

**Step 0: prerequisites (by hand)**

| # | Tool | Source | Package ID | Why first |
|---|------|--------|------------|-----------|
| 0 | chezmoi | winget | `twpayne.chezmoi` | Needed to clone this repo |

**Step 1: CLI tools, `bootstrap\install-cli.ps1`**

| # | Tool | Source | Package ID | What it's for |
|---|------|--------|------------|---------------|
| 1 | git | winget | `Git.Git` | Version control. First, because Scoop buckets and vcpkg need it |
| 2 | python | winget | `Python.Python.3.13` | Python 3.13 runtime |
| 3 | node | winget | `OpenJS.NodeJS.LTS` | Node.js LTS + npm |
| 4 | rustup | winget | `Rustlang.Rustup` | Rust toolchain manager (runs `rustup default stable` if no toolchain) |
| 5 | .NET SDK | winget | `Microsoft.DotNet.SDK.10` | .NET 10 SDK |
| 6 | LLVM | winget | `LLVM.LLVM` | clang, clangd, clang-format |
| 7 | nushell | winget | `Nushell.Nushell` | Shell |
| 8 | zellij | winget | `Zellij.Zellij` | Terminal multiplexer |
| 9 | Scoop | special | `irm get.scoop.sh \| iex` | User-level package manager for rows 10-19. Only installed if one of them is missing |
| 10 | ripgrep | scoop | `ripgrep` | Fast grep |
| 11 | fzf | scoop | `fzf` | Fuzzy finder |
| 12 | zoxide | scoop | `zoxide` | Smarter cd |
| 13 | starship | scoop | `starship` | Shell prompt |
| 14 | neovim | scoop | `neovim` | Editor |
| 15 | cmake | scoop | `cmake` | C/C++ build system generator |
| 16 | gh | scoop | `gh` | GitHub CLI |
| 17 | uv | scoop | `uv` | Python package/project manager |
| 18 | direnv | scoop | `direnv` | Per-directory env vars |
| 19 | chezmoi | scoop | `chezmoi` | Dotfiles manager (skipped if step 0 installed it) |
| 20 | vcpkg | special | git clone `microsoft/vcpkg` to `C:\Projects\_Tools\vcpkg` | C++ library manager. Bootstrapped, sets `VCPKG_ROOT`. Last, because it needs git |

Each Scoop row also checks a winget ID before installing (e.g. `Kitware.CMake`), so a tool already installed through winget is not installed a second time.

**Step 2: GUI apps, `bootstrap\install-gui.ps1`**

| # | Tool | Source | Package ID | What it's for |
|---|------|--------|------------|---------------|
| 21 | VS Code | winget | `Microsoft.VisualStudioCode` | Code editor |
| 22 | Notepad++ | winget | `Notepad++.Notepad++` | Text editor |
| 23 | Visual Studio 2026 | winget + `vs2026.vsconfig` | `Microsoft.VisualStudio.Community` | IDE + MSVC. Workloads: Core editor, .NET desktop, C++ desktop, C++ games, VS extension development |

**Step 3: configs**, `chezmoi apply`. This comes last, so nushell, starship and nvim exist when their configs land.

### Commands

```powershell
# Fresh machine (normal, non-admin PowerShell)
winget install twpayne.chezmoi
chezmoi init Y0L042/dotfiles                     # clone only, installs nothing
$b = "$(chezmoi source-path)\bootstrap"
powershell -ExecutionPolicy Bypass -File $b\install-cli.ps1 -DryRun   # report only
powershell -ExecutionPolicy Bypass -File $b\install-cli.ps1           # step 1
powershell -ExecutionPolicy Bypass -File $b\install-gui.ps1           # step 2
chezmoi apply                                    # step 3

# Existing VS 2026: add any workloads from vs2026.vsconfig that are missing (never removes)
powershell -ExecutionPolicy Bypass -File $b\install-gui.ps1 -ApplyVsConfig
```

Upgrades are not part of the bootstrap. Run `winget upgrade --all` and `scoop update *` when you want them.

## Daily use

```nu
chezmoi edit --apply ~/.config/starship.toml   # edit source + apply
chezmoi re-add                                 # or: edited the live file? pull it back in
chezmoi add <new-file>                         # start tracking a file
chezmoi diff / chezmoi status                  # what would change
chezmoi cd                                     # opens nu in the source repo -> git add/commit/push
chezmoi update                                 # pull + apply on another machine
```
