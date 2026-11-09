-- Telescope cache management
-- Large telescope history can cause memory issues

local data_path = vim.fn.stdpath('data')

-- Function to check telescope data size
local function check_telescope_data()
    local telescope_data = data_path .. '/telescope_history'
    local stat = vim.loop.fs_stat(telescope_data)

    if stat then
        print(string.format("Telescope history: %.2f MB", stat.size / 1024 / 1024))
    else
        print("No telescope history found")
    end

    -- Check for other large cache files
    local shada_file = vim.fn.expand('~/.local/share/nvim/shada/main.shada')
    local shada_stat = vim.loop.fs_stat(shada_file)
    if shada_stat then
        print(string.format("Shada file: %.2f MB", shada_stat.size / 1024 / 1024))
        if shada_stat.size > 50 * 1024 * 1024 then
            print("WARNING: Shada file is very large! Consider :wshada!")
        end
    end
end

-- Command to check cache sizes
vim.api.nvim_create_user_command('CacheCheck', check_telescope_data, {})

-- Limit shada file size to prevent bloat
vim.opt.shada = {
    "!",  -- Save and restore global variables
    "'100", -- Save marks for last 100 files (reduced from default)
    "<50", -- Maximum lines for each register (reduced)
    "s10", -- Maximum size of an item in KiB (reduced from default)
    "h",  -- Disable hlsearch on load
}

print("Cache management loaded. Use :CacheCheck to check cache sizes")
