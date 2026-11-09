# Copilot Instructions for Neovim Config Workspace

This workspace is a modular Neovim configuration, organized for maintainability and extensibility. AI agents should follow these guidelines to be productive:

## Architecture Overview
- **Entry Point:** `init.lua` orchestrates config loading in three phases: `prelazy`, `lazy`, and `postlazy`.
    - **prelazy/**: Early system, environment, and option setup. Key files: `system_setup.lua`, `env.lua`, `options.lua`, `functions.lua`, `keymaps.lua`.
    - **lazy/**: Bootstraps and configures the `lazy.nvim` plugin manager (`lazy.lua`). Plugins are loaded from the `plugins/` directory.
    - **postlazy/**: Late customizations, filetype-specific settings, and additional keymaps/functions.
- **Plugins:** Managed via `lazy.nvim`. Each plugin has its own config file in `plugins/`. Use the `event` and `dependencies` fields for lazy loading and plugin relationships.
- **Backup/Temp Plugins:** `plugins_backup/` and `plugins_temp/` hold alternate or experimental plugin configs.

## Developer Workflows
- **Reloading Config:** Restart Neovim after config changes. For plugin changes, use `:Lazy sync`.
- **Keymaps:** Custom keymaps are defined in `prelazy/keymaps.lua` and `postlazy/keymaps.lua`. Examples:
    - `<F2>`: Save file (normal/insert mode)
    - `<F5>`: Save all tabs
    - `<F9>`: Toggle word wrap
    - `<Esc>`: Clear search highlights
    - `<Leader>mt`: Toggle MSYS2 Bash terminal (Windows only)
    - `<A-;>`: Toggle semicolon at end of line
- **Filetype Settings:** See `postlazy/file_functions.lua` for filetype-specific indentation rules.
- **Environment Detection:** `prelazy/env.lua` sets global flags based on `COMPUTER_ID` for device-specific config.

## Project-Specific Patterns
- **Global Functions:** Utility functions (e.g., `save_all_tabs`, `toggle_semicolon`) are defined as globals in `functions.lua` files and mapped to keys.
- **Autocommands:** Used for filetype settings and highlighting (see `postlazy/file_functions.lua`, `postlazy/functions.lua`).
- **Plugin Spec:** Plugins are specified as Lua tables, with lazy loading and dependencies explicit.
- **Helper Utilities:** Use `config/utils.lua` for requiring all modules in a directory.

## Integration Points
- **External Shell:** Windows users: Shell is set to MSYS2 Bash (`prelazy/system_setup.lua`).
- **LSP:** LSP servers managed via `mason.nvim` and `mason-lspconfig.nvim` (see `plugins/mason_lsp.lua`).

## Conventions
- **Phased Loading:** Respect the three-phase config structure for ordering changes.
- **Keymap Consistency:** Add new keymaps in the appropriate phase file.
- **Plugin Management:** Add new plugins to `plugins/` and update `lazy.lua` if needed.
- **Device-Specific Logic:** Use global flags from `env.lua` for conditional config.

## Examples
- To add a new plugin: Create a Lua file in `plugins/`, then ensure it's imported via `lazy.lua`.
- To add a keymap: Place in `prelazy/keymaps.lua` (early) or `postlazy/keymaps.lua` (late).
- To set filetype options: Add an autocommand in `postlazy/file_functions.lua`.

---
For unclear or missing conventions, ask the user for clarification before making changes.
