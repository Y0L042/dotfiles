return {
  {
    "Olical/conjure",
    ft = { "clojure", "fennel", "python", "lisp", "commonlisp", "clisp", "rust" }, -- etc
    lazy = true,
    init = function()
      -- Set configuration options here
         vim.g['conjure#extract#tree_sitter#enabled'] = true

      -- Uncomment this to get verbose logging to help diagnose internal Conjure issues
      -- This is VERY helpful when reporting an issue with the project
      -- vim.g["conjure#debug"] = true
    end,

    -- Optional cmp-conjure integration
    dependencies = { "PaterJason/cmp-conjure" },
  },
  {
    "PaterJason/cmp-conjure",
    lazy = true,
    dependencies = { "hrsh7th/nvim-cmp" },
    config = function()
      local cmp = require("cmp")
      local config = cmp.get_config()
      table.insert(config.sources, { name = "conjure" })
      return cmp.setup(config)
    end,
  },

}