-- Memory debugging utilities
-- Add this to your postlazy config to monitor memory usage

-- Function to check Neovim's memory usage
local function check_memory()
    -- Get memory statistics
    local mem_kb = vim.fn.system("tasklist /FI \"IMAGENAME eq nvim.exe\" /FO CSV /NH"):match('(%d+) K')
    if mem_kb then
        local mem_mb = tonumber(mem_kb:gsub(',', '')) / 1024
        print(string.format("Neovim Memory Usage: %.2f MB", mem_mb))
    end

    -- Get Lua memory usage
    local lua_mem = collectgarbage("count")
    print(string.format("Lua Memory Usage: %.2f MB", lua_mem / 1024))

    -- Get LSP client info
    local clients = vim.lsp.get_clients()
    print("Active LSP clients: " .. #clients)
    for _, client in ipairs(clients) do
        print(string.format("  - %s (buffers: %d)", client.name, #vim.lsp.get_buffers_by_client_id(client.id)))
    end

    -- Get buffer count
    local buffers = vim.api.nvim_list_bufs()
    local loaded_buffers = 0
    for _, buf in ipairs(buffers) do
        if vim.api.nvim_buf_is_loaded(buf) then
            loaded_buffers = loaded_buffers + 1
        end
    end
    print(string.format("Loaded buffers: %d / %d", loaded_buffers, #buffers))

    -- Get autocmd count
    local autocmds = vim.api.nvim_get_autocmds({})
    print("Total autocmds: " .. #autocmds)
end

-- Function to force garbage collection
local function force_gc()
    collectgarbage("collect")
    print("Garbage collection completed")
    check_memory()
end

-- Function to manually clean old buffers
local function clean_buffers()
    local buffers = vim.api.nvim_list_bufs()
    local current_buf = vim.api.nvim_get_current_buf()
    local deleted = 0

    for _, buf in ipairs(buffers) do
        if buf ~= current_buf and vim.api.nvim_buf_is_valid(buf) then
            local ok_mod, modified = pcall(vim.api.nvim_buf_get_option, buf, 'modified')
            local ok_listed, buflisted = pcall(vim.api.nvim_buf_get_option, buf, 'buflisted')

            -- Delete unmodified, unlisted, or unloaded buffers
            if (ok_mod and not modified) and (not ok_listed or not buflisted or not vim.api.nvim_buf_is_loaded(buf)) then
                pcall(vim.api.nvim_buf_delete, buf, { force = false, unload = true })
                deleted = deleted + 1
            end
        end
    end

    collectgarbage("collect")
    print(string.format("Cleaned %d buffers", deleted))
    check_memory()
end

-- Create commands
vim.api.nvim_create_user_command('MemCheck', check_memory, {})
vim.api.nvim_create_user_command('MemGC', force_gc, {})
vim.api.nvim_create_user_command('BufferClean', clean_buffers, {})

-- Keymaps
vim.keymap.set('n', '<leader>dm', check_memory, { desc = "Check memory usage" })
vim.keymap.set('n', '<leader>dg', force_gc, { desc = "Force garbage collection" })
vim.keymap.set('n', '<leader>db', clean_buffers, { desc = "Clean old buffers" })

-- Auto-check memory every 5 minutes (can be disabled)
-- Reduced frequency from 2 minutes to 5 minutes to minimize subprocess overhead
local interval = 300000 -- 5 minutes (was 120000)
local auto_check_enabled = true
if auto_check_enabled then
    vim.api.nvim_create_augroup('MemoryAutoCheck', { clear = true })
    local timer = vim.loop.new_timer()
    timer:start(interval, interval, vim.schedule_wrap(function()
        print("=== Auto Memory Check ===")
        check_memory()
    end))

    -- Clean up timer on exit
    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = 'MemoryAutoCheck',
        callback = function()
            if timer and not timer:is_closing() then
                timer:stop()
                timer:close()
            end
        end,
    })
end

-- Log memory on specific events to track growth with file size safety
local MAX_LOG_SIZE_MB = 50 -- Maximum log file size before rotation
local function log_memory_event(event_name)
    local lua_mem = collectgarbage("count") / 1024
    local log_file = vim.fn.stdpath('data') .. '/memory_log.txt'
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local line = string.format("%s | %s | Lua: %.2f MB\n", timestamp, event_name, lua_mem)

    -- Check log file size before writing to prevent unbounded growth
    local file_stat = vim.loop.fs_stat(log_file)
    if file_stat and file_stat.size > (MAX_LOG_SIZE_MB * 1024 * 1024) then
        -- Rotate log: rename old file and start fresh
        local backup_file = log_file .. '.old'
        os.remove(backup_file) -- Remove previous backup if it exists
        os.rename(log_file, backup_file)
        print(string.format("Memory log rotated (exceeded %d MB)", MAX_LOG_SIZE_MB))
    end

    local file = io.open(log_file, "a")
    if file then
        file:write(line)
        file:close()
    end
end

-- Track memory on key events with throttling to prevent memory spikes
local last_log_time = {}
local last_gc_time = 0
local LOG_THROTTLE_MS = 5000 -- Only log each event type once per 5 seconds (increased from 1s)
local GC_INTERVAL_MS = 30000 -- Suggest GC every 30 seconds during active operations

vim.api.nvim_create_augroup('MemoryLogging', { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "BufLeave", "LspAttach", "LspDetach" }, {
    group = 'MemoryLogging',
    callback = function(ev)
        local event_type = ev.event
        local now = vim.loop.now()
        local last_time = last_log_time[event_type] or 0

        -- Only log if enough time has passed since last log of this event type
        if now - last_time > LOG_THROTTLE_MS then
            log_memory_event(event_type .. " - " .. (vim.fn.bufname(ev.buf) or "unknown"))
            last_log_time[event_type] = now

            -- Periodic GC hint during active buffer operations to prevent accumulation
            if now - last_gc_time > GC_INTERVAL_MS then
                collectgarbage("step", 1000) -- Incremental GC step (non-blocking)
                last_gc_time = now
            end
        end
    end,
})

-- Buffer cleanup to prevent unbounded buffer accumulation
local MAX_BUFFERS = 50  -- Reduced from 100 to 50 for more aggressive cleanup
local buffer_cleanup_timer = nil

local function cleanup_old_buffers()
    local buffers = vim.api.nvim_list_bufs()
    local loaded = {}

    -- Collect loaded, listed buffers with metadata
    for _, buf in ipairs(buffers) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_is_valid(buf) then
            local ok, buflisted = pcall(vim.api.nvim_buf_get_option, buf, 'buflisted')
            if ok and buflisted then
                table.insert(loaded, {
                    bufnr = buf,
                    lastused = vim.fn.getbufinfo(buf)[1].lastused or 0,
                })
            end
        end
    end

    -- Sort by last used time (oldest first)
    table.sort(loaded, function(a, b)
        return a.lastused < b.lastused
    end)

    -- Delete oldest buffers if over limit
    local current_buf = vim.api.nvim_get_current_buf()
    local to_delete = #loaded - MAX_BUFFERS

    if to_delete > 0 then
        local deleted = 0
        for i = 1, #loaded do
            local buf = loaded[i].bufnr

            -- Don't delete current buffer or modified buffers
            if buf ~= current_buf then
                local ok_mod, modified = pcall(vim.api.nvim_buf_get_option, buf, 'modified')
                if ok_mod and not modified then
                    -- Try to delete/unload buffer
                    pcall(vim.api.nvim_buf_delete, buf, { force = false, unload = true })
                    deleted = deleted + 1

                    if deleted >= to_delete then
                        print(string.format("Buffer cleanup: removed %d old buffers (limit: %d)", deleted, MAX_BUFFERS))
                        collectgarbage("step", 500) -- Help GC reclaim memory
                        break
                    end
                end
            end
        end
    end
end

-- Setup timer-based buffer cleanup (replaces autocmd to prevent O(n²) storms)
local function setup_buffer_cleanup_timer()
    if buffer_cleanup_timer then
        buffer_cleanup_timer:stop()
        buffer_cleanup_timer:close()
    end

    buffer_cleanup_timer = vim.loop.new_timer()
    buffer_cleanup_timer:start(30000, 30000, vim.schedule_wrap(function()
        local loaded_bufs = vim.tbl_filter(function(buf)
            return vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted
        end, vim.api.nvim_list_bufs())

        if #loaded_bufs > MAX_BUFFERS then
            cleanup_old_buffers()
        end
    end))
end

-- Emergency commands to disable/enable buffer monitoring
vim.api.nvim_create_user_command('MemMonitorOff', function()
    if buffer_cleanup_timer then
        buffer_cleanup_timer:stop()
        buffer_cleanup_timer:close()
        buffer_cleanup_timer = nil
        print("Buffer monitoring disabled")
    end
end, { desc = "Disable automatic buffer cleanup monitoring" })

vim.api.nvim_create_user_command('MemMonitorOn', function()
    setup_buffer_cleanup_timer()
    print("Buffer monitoring enabled")
end, { desc = "Enable automatic buffer cleanup monitoring" })

-- Start buffer cleanup timer
setup_buffer_cleanup_timer()

-- Clean up timer on exit
vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
        if buffer_cleanup_timer and not buffer_cleanup_timer:is_closing() then
            buffer_cleanup_timer:stop()
            buffer_cleanup_timer:close()
        end
    end,
})

print("Memory debugging loaded. Use :MemCheck or <leader>dm to check memory")
print("Memory log: " .. vim.fn.stdpath('data') .. '/memory_log.txt')
print(string.format("Buffer limit: %d (auto-cleanup enabled)", MAX_BUFFERS))
