-- Enable loading of local configuration files (.nvim.lua, .nvimrc, etc.)
vim.o.exrc = true   -- Enable reading of local config files (like .nvim.lua)
vim.o.secure = true -- Ensure safe mode for untrusted configs


-- disable netrw at the very start of your init.lua FOR NVIM-TREE PLUGIN
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set UTF-8 encoding
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"
-- vim.opt.termencoding = "utf-8"

-- Disable vi compatibility (emulation of old bugs)
vim.opt.compatible = false

-- Use indentation of previous line
vim.opt.autoindent = true

-- Use intelligent indentation for C
vim.opt.smartindent = true
vim.opt.backspace = { 'indent', 'eol', 'start' }

-- Configure tab width and insert spaces instead of tabs
vim.opt.tabstop = 4      -- Tab width is 4 spaces
vim.opt.shiftwidth = 4   -- Indent also with 4 spaces
vim.opt.softtabstop = 4
vim.opt.expandtab = true -- Expand tabs to spaces

-- Force consistent tab behavior - do not copy indentation from existing files
vim.opt.copyindent = false   -- Do not copy the structure of existing indents
vim.opt.preserveindent = false -- Do not preserve existing indentation structure

-- Wrap lines at 80 chars.
vim.opt.textwidth = 80
vim.opt.colorcolumn = "81"


-- Turn syntax highlighting on
vim.cmd('syntax on')

-- Use ctag generated tags
vim.opt.tags = './.tags;/'

-- Turn line numbers on
vim.opt.number = true
vim.opt.relativenumber = true

-- Highlight matching braces
vim.opt.showmatch = true

-- Intelligent comments
vim.cmd('set comments=sl:/*,mb:\\ *,elx:\\ */')

-- Disable word wrap by default
vim.opt.wrap = false

-- Do not let cursor scroll below or above N number of lines when scrolling.
vim.opt.scrolloff = 10

-- Highlight searched terms
vim.opt.hlsearch = true

-- Highlight matches as you type
vim.opt.incsearch = true

-- Enable auto completion menu after pressing TAB
vim.opt.wildmenu = true

-- Make wildmenu behave like similar to Bash completion
vim.opt.wildmode = { 'list', 'longest' }

-- Ignore certain file types in wildmenu
vim.opt.wildignore = { '*.docx', '*.jpg', '*.png', '*.gif', '*.pdf', '*.pyc', '*.exe', '*.flv', '*.img', '*.xlsx' }

-- Highlight cursor line underneath the cursor horizontally
vim.opt.cursorline = true

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
-- Set the timeout length for leader key sequences
vim.opt.timeoutlen = 1500 -- Adjust this value as needed, 1000 ms = 1 second

vim.opt.fileformats = { "unix", "dos" }