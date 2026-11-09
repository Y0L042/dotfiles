-- Duin LSP — binding-aware daslang diagnostics for DuinEngine projects.
--
-- Unlike the generic `daslang-lsp` (which only knows daslib/builtin and false-flags every
-- dn_* call), this attaches DuinDasHost: a per-project warm daemon that has Duin's engine
-- modules registered. Architecture (docs/plans/DuinDasHost_plan.md):
--
--   nvim ──stdio LSP──> proxy.das (daslang.exe) ──WebSocket via .ddh──> DuinDasHost --serve-ws
--
-- The proxy only CONNECTS; spawning the shared daemon is THIS config's job (auto-spawn is
-- editor-side). One daemon per .das_project; it idles out after 30s with no connections.
--
-- Both this and the generic `daslang-lsp` target filetype `dascript`; inside a Duin project
-- this one wins (we detach the generic client per buffer). Outside a Duin project (no
-- .das_project above the file) this server does not start, so the generic one is unaffected.

-- ===== Config (adjust paths if your tree differs) =====
local DUIN_ROOT   = "D:/Projects/CPP_Projects/Duin"
local DASLANG_EXE = DUIN_ROOT .. "/Duin/vendor/daslang/bin/Debug/daslang.exe"
local PROXY_DAS   = DUIN_ROOT .. "/DuinDasHost/scripts/proxy.das"
local HOST_EXE    = DUIN_ROOT .. "/DuinDasHost/bin/Debug-windows-x86_64/DuinDasHost/DuinDasHost.exe"
local DAS_ROOT    = DUIN_ROOT .. "/Duin/vendor/daslang"

-- Returns true if a path segment looks like a build-output directory that should be skipped
-- when searching for .das_project files. The scripts in bin/ are copies of the source; we
-- always want the source project, not the build copy.
local function is_build_dir(dir)
  -- Match any path component named "bin" or "obj" or "build" or "out" (common build roots).
  -- We check the full path so nested dirs like "ExampleProjects/.../bin/..." are caught.
  return dir:find("/bin/", 1, true) ~= nil
      or dir:find("/obj/", 1, true) ~= nil
      or dir:find("/build/", 1, true) ~= nil
      or dir:find("/out/", 1, true) ~= nil
end

-- Walks up from `start_dir` to the nearest dir containing a *.das_project file. nvim is
-- typically opened at the Duin/ root and you browse between projects, so the project is
-- resolved PER FILE from the open buffer's path, not from nvim's cwd. Returns the first
-- (sorted, for stability) *.das_project in the nearest ancestor dir that has one.
-- Skips build-output directories (bin/, obj/, etc.) so the source project is always used.
local function find_project(start_dir)
  -- Normalize to forward slashes: fnamemodify yields backslashes on Windows, but
  -- vim.lsp.start's root_dir / workspace-folder URI matching expects forward slashes
  -- (a backslash root_dir silently breaks attachment).
  local dir = (start_dir:gsub("\\", "/"))
  for _ = 1, 64 do
    if not is_build_dir(dir) then
      local hits = vim.fn.globpath(dir, "*.das_project", false, true)
      if #hits > 0 then
        table.sort(hits)
        return (hits[1]:gsub("\\", "/")), dir
      end
    end
    local parent = (vim.fn.fnamemodify(dir, ":h"):gsub("\\", "/"))
    if parent == dir then break end
    dir = parent
  end
  return nil, nil
end

local function daemon_ddh_exists(project_file)
  return vim.fn.filereadable(project_file .. ".ddh") == 1
end

-- Returns true if the pid recorded in a file is still a running process.
local function pid_in_file_alive(path)
  local f = io.open(path, "r")
  if not f then return false end
  local content = f:read("*a")
  f:close()
  local pid = tonumber(content:match("%d+"))
  if not pid then return false end
  -- On Windows, tasklist /FI exits 0 even on no match; check stdout instead.
  local handle = io.popen('tasklist /FI "PID eq ' .. pid .. '" /NH 2>nul')
  if not handle then return false end
  local out = handle:read("*a")
  handle:close()
  return out:find(tostring(pid)) ~= nil
end

-- Returns true if a live (non-stale) daemon is running for this project.
local function daemon_is_live(project_file)
  local ddh = project_file .. ".ddh"
  if vim.fn.filereadable(ddh) ~= 1 then return false end
  return pid_in_file_alive(ddh)
end

-- Removes a stale .ddh (one whose recorded pid is dead). The proxy reads wsUrl from this
-- file and dials it blindly; a stale .ddh from a killed/crashed daemon points at a dead port,
-- so the proxy connects to nothing and silently drops all diagnostics. The daemon only
-- removes its own .ddh on *clean* exit (main.cpp), so SIGTERM/crash always orphans one.
local function remove_stale_ddh(project_file)
  local ddh = project_file .. ".ddh"
  if vim.fn.filereadable(ddh) == 1 and not pid_in_file_alive(ddh) then
    os.remove(ddh)
  end
end

-- Spawns the per-project daemon detached (survives this nvim). No-op if a live daemon exists.
local function ensure_daemon(project_file)
  if daemon_is_live(project_file) then return end
  -- Dead-but-present .ddh: clear it so neither this respawn nor the proxy trusts its dead port.
  remove_stale_ddh(project_file)
  if vim.fn.executable(HOST_EXE) ~= 1 then
    vim.notify("Duin LSP: HOST_EXE not executable: " .. HOST_EXE, vim.log.levels.ERROR)
    return
  end
  local log_path = project_file .. ".daemon.log"
  -- detach=true: daemon must outlive this nvim job. nvim's jobstart callbacks are disabled
  -- for detached jobs, so we redirect stderr to the log via cmd /c ... 2>logfile.
  -- Pass as argv array so the shell doesn't mangle quotes; env table sets DUIN_DAS_ROOT.
  -- stderr goes to /dev/null (detached jobs can't use on_stderr); the daemon itself never
  -- had log-to-file support, so we lose the stderr log when detached. The .ddh file is the
  -- liveness signal we actually care about.
  local job = vim.fn.jobstart(
    { HOST_EXE, "--serve-ws", "--project", project_file, "--idle-timeout", "300" },
    { detach = true, env = { DUIN_DAS_ROOT = DAS_ROOT } }
  )
  -- jobstart returns <= 0 on failure (0 = invalid args, -1 = not executable). Detached jobs
  -- get no on_exit callback, so this return value is our only spawn-failure signal.
  if job <= 0 then
    vim.notify("Duin LSP: failed to spawn daemon (jobstart=" .. tostring(job) .. ") for " .. project_file, vim.log.levels.ERROR)
    return
  end
  -- Wait for the daemon to write a *live* .ddh (not just any readable file — a stale .ddh
  -- from a prior dead daemon would also pass daemon_ddh_exists but has a dead port). We poll
  -- daemon_is_live which also checks that the recorded pid is actually running.
  if not vim.wait(8000, function() return daemon_is_live(project_file) end, 150) then
    vim.notify("Duin LSP: daemon did not become live within 8s (see " .. project_file .. ".daemon.log)", vim.log.levels.WARN)
  end
end

local function start_duin_lsp(bufnr)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  if fname == "" then return end
  local file_dir = vim.fn.fnamemodify(fname, ":p:h")
  local project_file, project_dir = find_project(file_dir)
  if not project_file then return end  -- not a Duin project; leave to other servers

  ensure_daemon(project_file)

  local ok, client_id = pcall(vim.lsp.start, {
    name = "duin_lsp",
    cmd = { DASLANG_EXE, PROXY_DAS },
    root_dir = project_dir,  -- proxy reads rootUri to find the .das_project + its .ddh
    flags = {
      debounce_text_changes = 1500,  -- ms idle after last keystroke before sending didChange
    },
  }, { bufnr = bufnr })
  if not ok then
    vim.notify("Duin LSP: vim.lsp.start error: " .. tostring(client_id), vim.log.levels.ERROR)
  elseif not client_id then
    vim.notify("Duin LSP: vim.lsp.start returned nil (client failed to start)", vim.log.levels.WARN)
  else
    vim.notify("Duin LSP: started client id=" .. tostring(client_id) .. " root=" .. project_dir, vim.log.levels.INFO)
  end

  -- The generic `daslang` server is wrong inside a Duin project; detach it from this buffer.
  -- vim.schedule(function()
  --   for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "daslang" })) do
  --     vim.lsp.buf_detach_client(bufnr, c.id)
  --   end
  -- end)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = {"dascript", "daslang"},
  callback = function(args) start_duin_lsp(args.buf) end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "duin_lsp" then return end
    local b = args.buf
    -- Force a recompile/refresh of diagnostics for the current buffer. The daemon may have
    -- idled out since attach, so ensure it's live first — the proxy reconnects lazily but
    -- cannot itself spawn the daemon (that's our job).
    vim.keymap.set("n", "<leader>dr", function()
      local fname = vim.api.nvim_buf_get_name(b)
      if fname ~= "" then
        local pf = find_project(vim.fn.fnamemodify(fname, ":p:h"))
        if pf then ensure_daemon(pf) end
      end
      client.notify("textDocument/didSave", { textDocument = { uri = vim.uri_from_bufnr(b) } })
    end, { buffer = b, desc = "Duin: refresh diagnostics" })
    vim.keymap.set("n", "gd",  vim.lsp.buf.definition,  { buffer = b, desc = "Duin: goto definition" })
    vim.keymap.set("n", "gr",  vim.lsp.buf.references,  { buffer = b, desc = "Duin: find references" })
    vim.keymap.set("n", "K",   vim.lsp.buf.hover,        { buffer = b, desc = "Duin: hover" })
  end,
})

-- :DuinRefresh — tell the daemon to re-read engine .das modules from disk (RefreshBindings),
-- then recompile the current buffer so diagnostics reflect the updated engine scripts.
vim.api.nvim_create_user_command("DuinRefresh", function()
  local b = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = b, name = "duin_lsp" })
  if #clients == 0 then
    vim.notify("Duin LSP: no duin_lsp client attached to this buffer", vim.log.levels.WARN)
    return
  end
  local uri = vim.uri_from_bufnr(b)
  clients[1].request("workspace/executeCommand", {
    command = "duin.refreshBindings",
    arguments = { uri },
  }, function(err, _)
    if err then
      vim.notify("Duin LSP: refreshBindings error: " .. tostring(err.message), vim.log.levels.ERROR)
    end
  end, b)
end, { desc = "Duin: refresh engine .das bindings (RefreshBindings) and recompile" })

-- :DuinLsp — manually (re)start the server for the current buffer.
vim.api.nvim_create_user_command("DuinLsp", function()
  start_duin_lsp(vim.api.nvim_get_current_buf())
end, {})

-- :DuinLspDebug — print exactly what the resolver sees (filetype, project, daemon, clients).
vim.api.nvim_create_user_command("DuinLspDebug", function()
  local b = vim.api.nvim_get_current_buf()
  local fname = vim.api.nvim_buf_get_name(b)
  local ft = vim.bo[b].filetype
  local file_dir = fname ~= "" and vim.fn.fnamemodify(fname, ":p:h") or "<no file>"
  local project_file, project_dir = find_project(file_dir)
  local lines = {
    "DuinLspDebug:",
    "  buffer file   = " .. fname,
    "  filetype      = " .. ft,
    "  file_dir      = " .. file_dir,
    "  project_file  = " .. tostring(project_file),
    "  project_dir   = " .. tostring(project_dir),
    "  .ddh exists   = " .. tostring(project_file and daemon_ddh_exists(project_file)) ..
    "  (live=" .. tostring(project_file and daemon_is_live(project_file)) .. ")",
    "  DASLANG_EXE   = " .. DASLANG_EXE .. "  (exists=" .. tostring(vim.fn.executable(DASLANG_EXE) == 1) .. ")",
    "  PROXY_DAS     = " .. PROXY_DAS .. "  (readable=" .. tostring(vim.fn.filereadable(PROXY_DAS) == 1) .. ")",
    "  HOST_EXE      = " .. HOST_EXE .. "  (exists=" .. tostring(vim.fn.executable(HOST_EXE) == 1) .. ")",
    "  daemon log    = " .. tostring(project_file and (project_file .. ".daemon.log")),
  }
  local clients = vim.lsp.get_clients({ bufnr = b })
  table.insert(lines, "  attached LSP clients:")
  if #clients == 0 then
    table.insert(lines, "    (none)")
  else
    for _, c in ipairs(clients) do
      table.insert(lines, "    - " .. c.name .. " (id=" .. c.id .. ", root=" .. tostring(c.config.root_dir) .. ")")
    end
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, {})


