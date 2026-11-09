-- LSP Log Configuration
-- Reduce LSP logging to prevent log file growth

-- Set LSP log level to ERROR only (prevents verbose logging)
vim.lsp.set_log_level("ERROR")

-- Limit LSP log file size
local log_path = vim.lsp.get_log_path()
print("LSP log file: " .. log_path)

-- Function to check and truncate LSP log if too large
local function check_lsp_log_size()
    local max_size = 10 * 1024 * 1024 -- 10MB max
    local stat = vim.loop.fs_stat(log_path)

    if stat and stat.size > max_size then
        print(string.format("LSP log too large (%.2f MB), truncating...", stat.size / 1024 / 1024))
        local file = io.open(log_path, "w")
        if file then
            file:write("Log truncated due to size\n")
            file:close()
        end
    end
end

-- Check log size on startup
vim.defer_fn(check_lsp_log_size, 1000)

-- Command to check LSP log
vim.api.nvim_create_user_command('LspLogCheck', function()
    local stat = vim.loop.fs_stat(log_path)
    if stat then
        print(string.format("LSP log size: %.2f MB", stat.size / 1024 / 1024))
        print("LSP log path: " .. log_path)
    else
        print("LSP log file not found")
    end
end, {})

-- Command to clear LSP log
vim.api.nvim_create_user_command('LspLogClear', function()
    local file = io.open(log_path, "w")
    if file then
        file:write("Log cleared\n")
        file:close()
        print("LSP log cleared")
    end
end, {})
