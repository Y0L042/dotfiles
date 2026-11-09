# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a modular Neovim configuration using a **three-phase initialization system**:

### Initialization Phases

1. **PreLazy Phase** (Before plugins load): [init.lua](init.lua) loads:
   - [lua/config/prelazy/system_setup.lua](lua/config/prelazy/system_setup.lua): MSYS2 Bash shell configuration (Windows)
   - [lua/config/prelazy/env.lua](lua/config/prelazy/env.lua): Device-specific flags via `COMPUTER_ID` environment variable
   - [lua/config/prelazy/options.lua](lua/config/prelazy/options.lua): Core Neovim settings
   - [lua/config/prelazy/functions.lua](lua/config/prelazy/functions.lua): Global utility functions in `_G` namespace
   - [lua/config/prelazy/keymaps.lua](lua/config/prelazy/keymaps.lua): Early keybindings

2. **Lazy Phase**: [lua/config/lazy.lua](lua/config/lazy.lua) bootstraps lazy.nvim and auto-imports all plugin definitions from [lua/plugins/](lua/plugins/)

3. **PostLazy Phase** (After plugins load):
   - [lua/config/postlazy/options.lua](lua/config/postlazy/options.lua): Late options (clipboard, formatoptions)
   - [lua/config/postlazy/functions.lua](lua/config/postlazy/functions.lua): Visual feedback (yank highlight, line-end toggles)
   - [lua/config/postlazy/file_functions.lua](lua/config/postlazy/file_functions.lua): Filetype settings and C/C++ header-source switching
   - [lua/config/postlazy/keymaps.lua](lua/config/postlazy/keymaps.lua): Additional keymaps
   - **Memory management modules**: `lsp_log_config.lua`, `cache_management.lua`, `debug_memory.lua`

### Plugin Management

- **Manager**: lazy.nvim with version locking via [lazy-lock.json](lazy-lock.json)
- **Loading**: Most plugins use `event = "VeryLazy"` for lazy loading
- **Structure**: Each plugin has its own file in [lua/plugins/](lua/plugins/) returning a spec table
- **Auto-updates**: Disabled by default (`checker = { enabled = false }`)

### LSP Configuration

Uses **Neovim 0.11+ built-in `vim.lsp.config()`** API instead of lspconfig's setup() pattern. See [lua/plugins/mason_lsp.lua](lua/plugins/mason_lsp.lua) for the modern approach:

```lua
vim.lsp.config('clangd', {
  cmd = { "clangd", "--background-index=false", ... },
  settings = { ... },
  root_dir = vim.fs.root(0, { ... }),
})
```

Language servers are managed via mason.nvim and configured with performance-conscious flags (especially clangd).

## Essential Commands

### Plugin Management
```vim
:Lazy sync       " Update/install plugins
:Lazy clean      " Remove unused plugins
:Lazy restore    " Restore from lazy-lock.json
:Lazy profile    " View startup performance
```

### Memory Diagnostics (Important for This Config)

This configuration has active memory optimization and monitoring:

```vim
:MemCheck        " Show memory usage, LSP clients, buffers
:MemGC           " Force garbage collection
:LspLogCheck     " Check LSP log file size
:LspLogClear     " Clear LSP log (auto-truncates at 10MB)
:CacheCheck      " Check Telescope/shada cache sizes

<leader>dm       " Memory check (keymap)
<leader>dg       " Garbage collection (keymap)
```

Memory is auto-checked every 30 seconds and logged to `%LOCALAPPDATA%\nvim-data\memory_log.txt`. See [MEMORY_DIAGNOSTIC_GUIDE.txt](MEMORY_DIAGNOSTIC_GUIDE.txt) for troubleshooting procedures.

### Key Development Keybindings

**Session Management:**
- `F3` / `:SessionSave` - Save session (manual, auto-save disabled)
- `<leader>ls` / `:SessionSearch` - Search/load sessions

**File Navigation:**
- `<leader>sf` - Telescope: Search files (uses `fd`)
- `<leader>sg` - Telescope: Live grep
- `<leader>sn` - Search Neovim config files
- `<A-n>` - Toggle nvim-tree

**LSP Operations:**
- `<leader>gdd/gds/gdv` - Go to definition (default/split/vertical)
- `<leader>rn` - Rename symbol
- `<leader>cf` - Format buffer
- `<leader>td` - Toggle diagnostics
- `]ge` / `[ge` - Next/previous diagnostic
- `<leader>ls` / `<leader>lS` - Start/stop LSP

**C/C++ Specific:**
- `F4` - Switch between header and source file
- `S-F4` - Switch and search for word under cursor

**Editing:**
- `F2` - Save file (normal/insert mode)
- `F5` - Save all buffers/tabs
- `F9` - Toggle word wrap
- `<A-;>` - Toggle semicolon at line end
- `<A-,>` - Toggle comma at line end
- `<leader>gj/gk` - Add blank lines below/above
- `<leader>t2` - Set tab width to 2 spaces and format document
- `<leader>t4` - Set tab width to 4 spaces and format document

## Important Patterns & Conventions

### Adding New Plugins

1. Create `lua/plugins/<plugin-name>.lua` with this structure:
```lua
return {
  {
    "author/plugin-name",
    event = "VeryLazy",  -- Lazy load for performance
    dependencies = {},
    config = function()
      require("plugin").setup({
        -- configuration
      })
    end,
  }
}
```

2. Run `:Lazy sync` to install
3. Restart Neovim to apply init.lua changes (use `:Lazy reload <plugin>` for plugin-only changes)

### Global Functions Pattern

Utility functions are defined in `_G` namespace for cross-module access:
```lua
_G.save_all_tabs = function() ... end
_G.is_netrw = function() ... end
```

### Device-Specific Configuration

Set `COMPUTER_ID` environment variable to enable device-specific features:
- `01` - Laptop Windows
- `11` - Laptop WSL2
- `101` - Narga (workstation)

Check global flags in config:
```lua
if is_env_laptop_win then
  -- Windows-specific config
end
```

## Special Considerations

### Windows Environment

- **Shell**: Uses MSYS2 Bash (`C:/msys64/usr/bin/bash.exe`) instead of cmd/PowerShell
- **Path handling**: `shellslash = true` for forward slashes
- **File finder**: Telescope uses `fd` (must be installed in MSYS2: `pacman -S fd`)
- **Terminal commands**: All shell integration runs through Bash

### Memory Management (Active Concern)

This configuration is actively optimized for memory usage:

**Primary Memory Considerations:**
- **clangd**: Background indexing disabled, limited completion results (50 items)
- **nvim-tree**: Filesystem watcher debounce increased to 500ms
- **LSP logs**: Auto-truncated at 10MB, monitored continuously
- **TreeSitter**: Auto-install disabled, minimal parser set
- **Auto-session**: Reduced session options (no terminal buffers, no localoptions)
- **Shada**: Limited history sizes

**When experiencing high memory usage:**
1. Run `:MemCheck` to identify culprits
2. Review [MEMORY_DIAGNOSTIC_GUIDE.txt](MEMORY_DIAGNOSTIC_GUIDE.txt) for step-by-step procedures
3. Test by disabling suspects one-by-one: nvim-tree, clangd, auto-session
4. Check LSP log size with `:LspLogCheck`
5. For clangd projects, consider adding `.clangd` config file with query driver settings

External monitoring scripts available: [mem_watch.bat](mem_watch.bat), [mem_watch.ps1](mem_watch.ps1), [mem_watch.sh](mem_watch.sh)

### C/C++ Development Workflow

- Custom header-source switching with position memory (F4/S-F4)
- Clangd configured with inlay hints (designators, parameters, deduced types)
- TreeSitter textobjects for navigation: `]f`/`[f` (functions), `]c`/`[c` (classes)
- C99 fallback flags for clangd compatibility
- Auto-formatting via LSP

### Session Management

- **Auto-save**: Disabled by default (manual save with F3)
- **Suppressed directories**: Home directory, Projects, Downloads, root
- **Session restoration**: Automatically highlights current file in nvim-tree (500ms delay)
- **Minimal session data**: Terminal buffers and localoptions excluded to reduce memory footprint

### Telescope Customization

- Custom path display format (filename-first)
- Extensive ignore patterns for build artifacts and binaries
- Previewer disabled by default for performance
- Uses `fd` for file finding (faster than built-in)
- See [lua/plugins/telescope.lua](lua/plugins/telescope.lua) for allow/deny patterns

## Testing Changes

1. **Init.lua changes**: Restart Neovim completely
2. **Plugin config changes**: Use `:Lazy reload <plugin>` or restart
3. **Health checks**: Run `:checkhealth` to diagnose issues
4. **Memory impact**: Monitor with `:MemCheck` and watch memory_log.txt
5. **Plugin testing**: Use `:Lazy profile` to check startup time impact

## Key Plugin Ecosystem

**Core Infrastructure:** lazy.nvim, mason.nvim, nvim-lspconfig, nvim-cmp, nvim-treesitter

**UI & Navigation:** telescope.nvim, nvim-tree.lua, lualine.nvim, flash.nvim

**LSP & Completion:** mason-lspconfig, cmp-nvim-lsp, cmp-buffer, cmp-path

**Editing:** Comment.nvim, vim-surround, autoclose.nvim, marks.nvim

**Development Tools:** ctrlsf.vim, toggleterm.nvim, auto-session, neogen

**Language-Specific:** nvim-java suite (Java development)

Full list with versions in [lazy-lock.json](lazy-lock.json). Disabled plugins kept in [lua/plugins_disabled/](lua/plugins_disabled/) for reference.
