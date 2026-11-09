-- Helper function to require all Lua modules in a given directory.
local function require_all_modules(directory, prefix)
  -- Use Neovim's API to scan the directory.
  local scan = vim.loop.fs_scandir
  local fd = scan(directory)
  if not fd then return end -- Exit if directory cannot be scanned
  while true do
    local name, type = vim.loop.fs_scandir_next(fd)
    if not name then break end               -- No more files
    if type == 'file' and name:match("%.lua$") then
      local module = name:gsub("%.lua$", "") -- Remove the '.lua' extension
      require(prefix .. module)              -- Load the module with the given prefix
    end
  end
end
