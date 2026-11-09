-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})


-- Define a function to toggle a semicolon at the end of the line
_G.toggle_semicolon = function()
    local line = vim.fn.getline('.')   -- Get the current line
    local cursor_pos = vim.fn.col('.') -- Save the cursor position
    if line:match(";$") then
        -- Remove semicolon if present
        vim.fn.setline('.', line:sub(1, -2))
    else
        -- Add semicolon if absent
        vim.fn.setline('.', line .. ';')
    end
    vim.fn.cursor(0, cursor_pos) -- Restore cursor position
end
-- Map Alt+; in normal mode
vim.api.nvim_set_keymap('n', '<A-;>', '<cmd>lua toggle_semicolon()<CR>', { noremap = true, silent = true })
-- Map Alt+; in insert mode
vim.api.nvim_set_keymap('i', '<A-;>', '<C-o><cmd>lua toggle_semicolon()<CR>', { noremap = true, silent = true })

-- Define a function to toggle a comma at the end of the line
_G.toggle_comma = function()
    local line = vim.fn.getline('.')   -- Get the current line
    local cursor_pos = vim.fn.col('.') -- Save the cursor position
    if line:match(",$") then
        -- Remove comma if present
        vim.fn.setline('.', line:sub(1, -2))
    else
        -- Add comma if absent
        vim.fn.setline('.', line .. ',')
    end
    vim.fn.cursor(0, cursor_pos) -- Restore cursor position
end
-- Map Alt+, in normal mode
vim.api.nvim_set_keymap('n', '<A-,>', '<cmd>lua toggle_comma()<CR>', { noremap = true, silent = true })
-- Map Alt+, in insert mode
vim.api.nvim_set_keymap('i', '<A-,>', '<C-o><cmd>lua toggle_comma()<CR>', { noremap = true, silent = true })
