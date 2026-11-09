-- File-specific Settings
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "cpp" },
    callback = function()
        -- Set settings for web-related files
        vim.opt_local.shiftwidth = 4
        vim.opt_local.tabstop = 4
        vim.opt_local.softtabstop = 4
        vim.opt_local.expandtab = true
    end,
})
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "nasm", "asm" },
    callback = function()
        -- Set settings for web-related files
        vim.opt_local.shiftwidth = 2
        vim.opt_local.tabstop = 2
        vim.opt_local.expandtab = true
    end,
})
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "c", "cpp", "h", "hpp" },
    callback = function()
        -- Set settings for web-related files
        vim.opt_local.shiftwidth = 4
        vim.opt_local.tabstop = 4
        vim.opt_local.softtabstop = 4
        vim.opt_local.expandtab = true
    end,
})
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "gd", "tres", "tscn" },
    callback = function()
        -- Set settings for web-related files
        vim.opt_local.shiftwidth = 4
        vim.opt_local.tabstop = 4
        vim.opt_local.softtabstop = 4
        vim.opt_local.expandtab = false
    end,
})


vim.api.nvim_create_autocmd("FileType", {
    pattern = { "h", "hpp", "c", "cpp", "cxx" },
    callback = function()
        vim.opt_local.autoindent = true
        vim.opt_local.smartindent = false

        -- Function to switch between header and source files
        function switch_source_header()
            -- Update (save) the current file before switching
            vim.cmd('update')

            local filepath = vim.fn.expand('%:p')
            local filename = vim.fn.expand('%:t')
            local dir = vim.fn.expand('%:p:h')
            local base = vim.fn.expand('%:t:r')

            local header_extensions = { '.h', '.hpp' }
            local source_extensions = { '.c', '.cpp', '.cc', '.cxx' }

            local current_ext = vim.fn.expand('%:e')
            local target_files = {}

            -- Save the current position in a global table with LRU cleanup
            local MAX_FILE_POSITIONS = 50
            local file_pos = vim.g.file_positions or {}
            file_pos[filepath] = { line = vim.fn.line('.'), col = vim.fn.col('.') }

            -- Implement simple LRU: remove oldest entry if table exceeds max size
            if vim.tbl_count(file_pos) > MAX_FILE_POSITIONS then
                -- Remove the first entry (simple FIFO approximation of LRU)
                local oldest_key = next(file_pos)
                if oldest_key then
                    file_pos[oldest_key] = nil
                end
                -- Hint GC after cleanup to reclaim memory immediately
                collectgarbage("step", 100)
            end

            vim.g.file_positions = file_pos

            if vim.tbl_contains(header_extensions, '.' .. current_ext) then
                for _, ext in ipairs(source_extensions) do
                    table.insert(target_files, dir .. '/' .. base .. ext)
                end
            elseif vim.tbl_contains(source_extensions, '.' .. current_ext) then
                for _, ext in ipairs(header_extensions) do
                    table.insert(target_files, dir .. '/' .. base .. ext)
                end
            else
                vim.notify("Not a recognized header/source file.", vim.log.levels.WARN)
                return
            end

            for _, file in ipairs(target_files) do
                if vim.fn.filereadable(file) == 1 then
                    -- vim.cmd('edit ' .. vim.fn.fnameescape(file))
                    vim.cmd('badd ' .. vim.fn.fnameescape(file))
                    vim.cmd('buffer ' .. vim.fn.fnameescape(file))
                    -- Restore cursor position in the target file
                    local target_pos = file_pos[file]
                    if target_pos then
                        vim.fn.cursor(target_pos.line, target_pos.col)
                    end
                    return
                end
            end

            vim.notify("Corresponding file not found.", vim.log.levels.INFO)
        end

        -- Function to switch files and set search
        function switch_and_search()
            -- Update (save) the current file before switching and searching
            vim.cmd('update')

            local mode = vim.fn.mode()
            if mode == 'v' or mode == 'V' or mode == '\22' then
                vim.cmd('noau normal! gv"zy')
                vim.fn.setreg('/', vim.fn.getreg('z'))
            else
                vim.fn.setreg('/', vim.fn.expand('<cword>'))
            end

            switch_source_header()

            -- Optional: Jump to the first search match
            if vim.fn.search(vim.fn.getreg('/'), 'n') == 0 then
                vim.notify("Search match not found.", vim.log.levels.INFO)
            else
                vim.cmd('normal! nzt')
            end
        end

        -- Key mappings for switching files

        -- F4: Switch between header and source
        vim.api.nvim_set_keymap('n', '<F4>', '<cmd>lua switch_source_header()<CR>', { noremap = true, silent = true })
        vim.api.nvim_set_keymap('i', '<F4>', '<Esc><cmd>lua switch_source_header()<CR>',
            { noremap = true, silent = true })
        vim.api.nvim_set_keymap('v', '<F4>', '<Esc><cmd>lua switch_source_header()<CR>',
            { noremap = true, silent = true })

        -- Shift+F4: Switch and search
        vim.api.nvim_set_keymap('n', '<S-F4>', '<cmd>lua switch_and_search()<CR>', { noremap = true, silent = true })
        vim.api.nvim_set_keymap('i', '<S-F4>', '<Esc><cmd>lua switch_and_search()<CR>', { noremap = true, silent = true })
        vim.api.nvim_set_keymap('v', '<S-F4>', '<Esc><cmd>lua switch_and_search()<CR>', { noremap = true, silent = true })

        -- [[ and ]] jump between function/class definitions
        -- Matches: lines at col 0 ending with { (1TBS style), or bare { at col 0 (Allman style)
        local c_skip_kw = { 'if', 'for', 'while', 'switch', 'do', 'else', 'return' }
        local function c_jump(dir)
            local flags = dir == 'b' and 'bW' or 'W'
            for _ = 1, 100 do
                local found = vim.fn.search([[\v^([A-Za-z_~*][^\n]*\{|\{)\s*$]], flags)
                if found == 0 then return end
                local line = vim.fn.getline('.')
                -- Bare { at col 0 (Allman style): accept immediately
                if line:match('^%s*{%s*$') then return end
                local skip = false
                for _, kw in ipairs(c_skip_kw) do
                    if line:match('^' .. kw .. '[%s%(]') then skip = true; break end
                end
                if not skip then return end
            end
        end
        vim.keymap.set({ 'n', 'x' }, '[[', function() c_jump('b') end, { buffer = true, silent = true })
        vim.keymap.set({ 'n', 'x' }, ']]', function() c_jump('f') end, { buffer = true, silent = true })
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "dascript", "das", "daslang", "das_project", "das_module" },
    callback = function()
        vim.opt_local.cindent = false
        vim.opt_local.smartindent = false
        vim.opt_local.indentexpr = ""
        vim.opt_local.autoindent = true
        -- Disable automatic line breaking at textwidth
        vim.opt_local.textwidth = 0
        vim.opt_local.formatoptions:remove({ "t", "c" })
        -- Indent after lines ending with {
        vim.opt_local.indentexpr = "v:lua.das_indent()"
        -- Only trigger reindent on new lines and brace characters, not on ':' (used for type annotations)
        vim.opt_local.indentkeys = "0{,0},o,O"
        -- Comment string for Comment.nvim / commentstring
        vim.bo.commentstring = "// %s"

        -- [[ and ]] jump between top-level def blocks
        local function das_jump(dir)
            vim.fn.search([[\v^\s*def\s]], dir == 'b' and 'bW' or 'W')
        end
        vim.keymap.set({ 'n', 'x' }, '[[', function() das_jump('b') end, { buffer = true, silent = true })
        vim.keymap.set({ 'n', 'x' }, ']]', function() das_jump('f') end, { buffer = true, silent = true })
    end,
})

function _G.das_indent()
    local lnum = vim.v.lnum - 1
    if lnum <= 0 then return 0 end

    -- Closing brace: scan back past empty lines to determine correct indent
    local cur_line = vim.fn.getline(vim.v.lnum)
    if cur_line:match("^%s*}") then
        local scan = lnum
        while scan >= 1 do
            local line = vim.fn.getline(scan)
            if not line:match("^%s*$") then
                local indent = vim.fn.indent(scan)
                -- If the scanned line opened the block, return its indent level
                if line:match("{%s*$") then
                    return indent
                end
                -- Otherwise the content inside the block tells us: dedent by one
                return math.max(0, indent - vim.bo.shiftwidth)
            end
            scan = scan - 1
        end
        return 0
    end

    -- For all other lines, skip empty previous lines so blank lines inside
    -- a block don't reset indent to 0
    local prev_line = vim.fn.getline(lnum)
    local prev_indent = vim.fn.indent(lnum)
    while lnum > 1 and prev_line:match("^%s*$") do
        lnum = lnum - 1
        prev_line = vim.fn.getline(lnum)
        prev_indent = vim.fn.indent(lnum)
    end

    if prev_line:match("{%s*$") then
        return prev_indent + vim.bo.shiftwidth
    end
    return prev_indent
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "lisp", "commonlisp" },
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.expandtab = true
        vim.opt_local.autoindent = true
        vim.opt_local.smartindent = false
        vim.opt_local.cindent = false
        vim.opt_local.textwidth = 0
        vim.opt_local.formatoptions:remove({ "t", "c" })
        vim.bo.commentstring = ";; %s"
    end,
})