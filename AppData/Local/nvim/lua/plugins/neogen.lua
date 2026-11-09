return {
    {
        "danymat/neogen",
        event = "VeryLazy",
        config = function()
            require("neogen").setup({
                input_after_comment = true,
                languages = {
                    cpp = {
                        template = {
                            annotation_convention = "doxygen" -- Set to Doxygen style for C++
                        }
                    }
                }
            })
            local opts = { noremap = true, silent = false } -- Added opts for key mapping options
            vim.api.nvim_set_keymap("n", "<Leader>dh", ":lua require('neogen').generate({ type = 'file' })<CR>", opts)
            vim.api.nvim_set_keymap("n", "<Leader>dc", ":lua require('neogen').generate({ type = 'class' })<CR>", opts)
            vim.api.nvim_set_keymap("n", "<Leader>df", ":lua require('neogen').generate({ type = 'func' })<CR>", opts)
        end
    }
}
