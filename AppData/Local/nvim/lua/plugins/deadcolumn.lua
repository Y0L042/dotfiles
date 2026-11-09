return {
        { 
        'Bekaboo/deadcolumn.nvim',
        event = "VeryLazy",
           config = function()
                local opts = {
                    scope = 'buffer', ---@type string|fun(): integer
                    ---@type string[]|fun(mode: string): boolean
                    modes = function(mode)
                        return mode:find('^[nictRss\x13]') ~= nil
                    end,
                    blending = {
                        threshold = 0.1,
                        colorcode = '#000000',
                        hlgroup = { 'Normal', 'bg' } -- { 'Normal', 'bg' },
                    },
                    warning = {
                        alpha = 0.4,
                        offset = 0,
                        colorcode = '#FF0000',
                        hlgroup = { 'Error', 'bg' },
                    },
                    extra = {
                        ---@type string?
                        follow_tw = nil,
                    },
                }
                require('deadcolumn').setup(opts) -- Call the setup function
            end,
    },

}
