require("config.utils")

-- PreLazy
require("config.prelazy.system_setup")
require("config.prelazy.env")
require("config.prelazy.options")
require("config.prelazy.functions")
require("config.prelazy.keymaps")

-- Lazy
require("config.lazy")

-- PostLazy
require("config.postlazy.options")
require("config.postlazy.functions")
require("config.postlazy.file_functions")
require("config.postlazy.keymaps")
require("config.postlazy.duin_lsp")


-- require("config.postlazy.lsp_log_config")   -- LSP log management
-- require("config.postlazy.cache_management") -- Cache/shada management
-- require("config.postlazy.debug_memory")     -- Memory debugging tools
