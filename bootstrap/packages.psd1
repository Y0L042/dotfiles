# Package lists for bootstrap\install-cli.ps1 and bootstrap\install-gui.ps1.
# This file is the source of truth: keep the tool tables in README.md in sync.
#
# Entry fields:
#   Name      display name
#   Purpose   short description (README / report only)
#   Command   executable looked up on PATH to detect an existing install (any source)
#   Paths     extra file paths that count as "installed" (env vars like %LOCALAPPDATA% are expanded)
#   WingetId  install with winget            } exactly one of these two,
#   Scoop     install with scoop (main bucket) } unless Kind is set
#   Kind      special handler: 'scoop' (Scoop itself), 'vcpkg', 'vs' (Visual Studio)
#   DetectWinget  (scoop entries) winget ID that also counts as "installed", so a tool
#                 installed with winget but not on PATH is not duplicated through Scoop
#   After     follow-up action after a fresh install: 'rustup-default-stable'
#
# Detection order: Command on PATH -> Paths -> winget list (WingetId/DetectWinget) -> scoop prefix.
# Anything found is skipped; nothing is ever upgraded or downgraded.
@{
    # Extra Scoop buckets to add before installing Scoop packages (main is always there).
    ScoopBuckets = @()

    Cli = @(
        # --- winget: runtimes and tools with real installers (git first: Scoop needs it) ---
        @{ Name = 'git';      Command = 'git';    WingetId = 'Git.Git';                 Purpose = 'Version control' }
        @{ Name = 'python';   Command = 'python'; WingetId = 'Python.Python.3.13';      Purpose = 'Python 3.13 runtime' }
        @{ Name = 'node';     Command = 'node';   WingetId = 'OpenJS.NodeJS.LTS';       Purpose = 'Node.js LTS + npm' }
        @{ Name = 'rustup';   Command = 'rustup'; WingetId = 'Rustlang.Rustup';         Purpose = 'Rust toolchain manager'; After = 'rustup-default-stable' }
        @{ Name = '.NET SDK'; Command = 'dotnet'; WingetId = 'Microsoft.DotNet.SDK.10'; Purpose = '.NET 10 SDK' }
        @{ Name = 'LLVM';     Command = 'clangd'; WingetId = 'LLVM.LLVM';               Purpose = 'clang, clangd, clang-format' }
        @{ Name = 'nushell';  Command = 'nu';     WingetId = 'Nushell.Nushell';         Purpose = 'Shell' }
        @{ Name = 'zellij';   Command = 'zellij'; WingetId = 'Zellij.Zellij';           Purpose = 'Terminal multiplexer' }

        # --- Scoop itself (only installed if a Scoop package below is missing) ---
        @{ Name = 'Scoop'; Kind = 'scoop'; Purpose = 'User-level package manager for the CLI tools below' }

        # --- scoop: portable CLI tools ---
        @{ Name = 'ripgrep';  Command = 'rg';       Scoop = 'ripgrep';  DetectWinget = 'BurntSushi.ripgrep.MSVC'; Purpose = 'Fast grep' }
        @{ Name = 'fzf';      Command = 'fzf';      Scoop = 'fzf';      DetectWinget = 'junegunn.fzf';            Purpose = 'Fuzzy finder' }
        @{ Name = 'zoxide';   Command = 'zoxide';   Scoop = 'zoxide';   DetectWinget = 'ajeetdsouza.zoxide';      Purpose = 'Smarter cd' }
        @{ Name = 'starship'; Command = 'starship'; Scoop = 'starship'; DetectWinget = 'Starship.Starship';       Purpose = 'Shell prompt' }
        @{ Name = 'neovim';   Command = 'nvim';     Scoop = 'neovim';   DetectWinget = 'Neovim.Neovim';           Purpose = 'Editor' }
        @{ Name = 'cmake';    Command = 'cmake';    Scoop = 'cmake';    DetectWinget = 'Kitware.CMake';           Purpose = 'C/C++ build system generator' }
        @{ Name = 'gh';       Command = 'gh';       Scoop = 'gh';       DetectWinget = 'GitHub.cli';              Purpose = 'GitHub CLI' }
        @{ Name = 'uv';       Command = 'uv';       Scoop = 'uv';       DetectWinget = 'astral-sh.uv';            Purpose = 'Python package/project manager' }
        @{ Name = 'direnv';   Command = 'direnv';   Scoop = 'direnv';   DetectWinget = 'direnv.direnv';           Purpose = 'Per-directory env vars' }
        @{ Name = 'chezmoi';  Command = 'chezmoi';  Scoop = 'chezmoi';  DetectWinget = 'twpayne.chezmoi';         Purpose = 'Dotfiles manager' }

        # --- special: not from a package manager ---
        @{ Name = 'vcpkg'; Kind = 'vcpkg'; Root = 'C:\Projects\_Tools\vcpkg'; Purpose = 'C++ library manager (git clone + bootstrap, sets VCPKG_ROOT)' }
    )

    Gui = @(
        @{ Name = 'VS Code';   Command = 'code'; WingetId = 'Microsoft.VisualStudioCode'; Purpose = 'Code editor' }
        @{ Name = 'Notepad++'; WingetId = 'Notepad++.Notepad++'; Paths = @('C:\Program Files\Notepad++\notepad++.exe'); Purpose = 'Text editor' }
        @{ Name = 'Visual Studio 2026'; Kind = 'vs'; WingetId = 'Microsoft.VisualStudio.Community'; VersionRange = '[18.0,19.0)'; Config = 'vs2026.vsconfig'; Purpose = 'IDE + MSVC (workloads from vs2026.vsconfig)' }
    )
}
