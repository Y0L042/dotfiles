return {
    {
        'nvim-focus/focus.nvim',
        version = '*',
        lazy = true,
        -- event = "VeryLazy",
        config = function()
            local focus_enabled = true  -- Track focus state

            -- Setup autocommands to disable Focus for certain buffer/file types
            local ignore_filetypes = { 'NvimTree' }  -- Added: list of filetypes to ignore
            local ignore_buftypes = { 'nofile', 'prompt', 'popup' }

            local augroup = vim.api.nvim_create_augroup('FocusDisable', { clear = true })

            vim.api.nvim_create_autocmd('WinEnter', {
                group = augroup,
                callback = function()
                    if vim.tbl_contains(ignore_buftypes, vim.bo.buftype) then
                        vim.w.focus_disable = true  -- Added: disable for the window
                    else
                        vim.w.focus_disable = false
                    end
                end,
                desc = 'Disable focus autoresize for BufType',
            })

            vim.api.nvim_create_autocmd('FileType', {
                group = augroup,
                callback = function()
                    if vim.tbl_contains(ignore_filetypes, vim.bo.filetype) then
                        vim.b.focus_disable = true  -- Added: disable for the buffer
                    else
                        vim.b.focus_disable = false
                    end
                end,
                desc = 'Disable focus autoresize for FileType',
            })

            -- Initial setup for the focus plugin
            require("focus").setup({
                enable = focus_enabled,
                commands = true,
                autoresize = {
                    enable = true,
                    width = 0,
                    height = 0,
                    minwidth = 0,
                    minheight = 0,
                    height_quickfix = 10,
                },
                split = {
                    bufnew = false,
                    tmux = false,
                },
                ui = {
                    number = false,
                    relativenumber = false,
                    hybridnumber = false,
                    absolutenumber_unfocussed = false,
                    cursorline = true,
                    cursorcolumn = false,
                    colorcolumn = {
                        enable = false,
                        list = '+1',
                    },
                    signcolumn = true,
                    winhighlight = false,
                }
            })

            -- F10 key mapping to toggle focus
            vim.keymap.set("n", "<F10>", function()
                if focus_enabled then
                    vim.g.focus_disable = true   -- Added: disable Focus globally
                    focus_enabled = false         -- Update the local state
                    vim.cmd("wincmd =")
                    print("Focus disabled globally")
                else
                    vim.g.focus_disable = false  -- Added: enable Focus globally
                    focus_enabled = true          -- Update the local state
                    print("Focus enabled globally")
                end

                -- Note: Not calling setup() again to avoid potential autocmd accumulation
                -- The plugin should respect vim.g.focus_disable without reconfiguration
            end)
        end
    },
}
