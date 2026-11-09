return
{
    {
        "Badhi/nvim-treesitter-cpp-tools",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        event = "VeryLazy",
        -- Optional: Configuration
        opts = function()
            local options = {
                preview = {
                    quit = "q", -- optional keymapping for quit preview
                    accept = "<tab>", -- optional keymapping for accept preview
                },
                header_extension = { "hpp", "h" }, -- optional
                source_extension = { "cpp", "c" }, -- optional
                custom_define_class_function_commands = { -- optional
                    TSCppImplWrite = {
                        output_handle = require("nt-cpp-tools.output_handlers").get_add_to_cpp(),
                    },
                    --[[
                    <your impl function custom command name> = {
                        output_handle = function (str, context) 
                            -- string contains the class implementation
                            -- do whatever you want to do with it
                        end
                    }
                    ]]
                },
            }
            return options
        end,
        -- End configuration
        config = true,
      keys = {
        -- implement out-of-class member functions (visual or normal)
        {
          "<leader>df",
          "<cmd>TSCppDefineClassFunc<CR>",
          mode = { "n", "v" },
          desc = "Define C++ class functions",
        },
        -- generate a concrete subclass implementing all pure-virtuals
        {
          "<leader>dc",
          "<cmd>TSCppMakeConcreteClass<CR>",
          desc = "Make concrete C++ class",
        },
        -- add missing Rule-of-3 special member functions
        {
          "<leader>d3",
          "<cmd>TSCppRuleOf3<CR>",
          desc = "Add C++ Rule of 3",
        },
        -- add missing Rule-of-5 special member functions
        {
          "<leader>d5",
          "<cmd>TSCppRuleOf5<CR>",
          desc = "Add C++ Rule of 5",
        },
      },
    }
}
