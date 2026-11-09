return {
	{
		"neovim/nvim-lspconfig",
		url = "https://github.com/neovim/nvim-lspconfig.git",
		-- Not lazy-loaded: the plugin ships server definitions in its `lsp/`
		-- directory, which must be on the runtimepath before `vim.lsp.enable()`.
		lazy = false,
		config = function()
			-- Server overrides. These are merged on top of the definitions that
			-- nvim-lspconfig provides in its `lsp/` directory.
			vim.lsp.config("rust_analyzer", {
				settings = {
					["rust-analyzer"] = {
						-- Run `cargo clippy` instead of `cargo check` for on-save diagnostics.
						checkOnSave = true,
						check = {
							command = "clippy",
							extraArgs = { "--all-targets" },
						},
						-- Separate target dir so clippy runs don't fight `cargo build`
						-- for the target/ lock.
						cargo = {
							targetDir = true,
						},
					},
				},
			})

			-- Servers to activate. Add names here as you install the binaries.
			vim.lsp.enable({
				-- "clangd",
				-- "lua_ls",
				"rust_analyzer",
			})

			vim.diagnostic.config({
				virtual_text = true,
				signs = false,
				update_in_insert = false,
				underline = true,
				severity_sort = true,
			})

			-- ==== Buffer-local keymaps, set only where a server attached ====
			vim.api.nvim_create_autocmd("LspAttach", {
				desc = "LSP keymaps",
				callback = function(args)
					local buf = args.buf
					local function map(mode, lhs, rhs, desc)
						vim.keymap.set(mode, lhs, rhs, { buffer = buf, noremap = true, silent = true, desc = desc })
					end

					-- Navigation
					map("n", "<leader>gdd", vim.lsp.buf.definition, "Go to definition")
					map("n", "<leader>gds", function()
						vim.cmd("split")
						vim.lsp.buf.definition()
					end, "Go to definition (horizontal split)")
					map("n", "<leader>gdv", function()
						vim.cmd("vsplit")
						vim.lsp.buf.definition()
					end, "Go to definition (vertical split)")
					map("n", "<leader>gD", vim.lsp.buf.declaration, "Go to declaration")
					map("n", "<leader>gi", vim.lsp.buf.implementation, "Go to implementation")
					map("n", "<leader>gt", vim.lsp.buf.type_definition, "Go to type definition")
					map("n", "<leader>gr", vim.lsp.buf.references, "Find references")

					-- Info
					map("n", "K", vim.lsp.buf.hover, "Hover documentation")
					map({ "n", "i" }, "<C-A>", vim.lsp.buf.signature_help, "Signature help")

					-- Edits
					map("n", "<leader>rn", function()
						vim.ui.input({ prompt = "Rename to: " }, function(new_name)
							if new_name and new_name ~= "" then
								vim.lsp.buf.rename(new_name)
							else
								vim.notify("Rename cancelled.", vim.log.levels.WARN)
							end
						end)
					end, "Rename symbol (with confirmation)")
					map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
					map("n", "<leader>cf", function()
						vim.lsp.buf.format({ async = true })
					end, "Format buffer")
				end,
			})

			-- ==== Global keymaps: diagnostics work without a client attached ====
			local function map(mode, lhs, rhs, desc)
				vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, desc = desc })
			end

			map("n", "]ge", function()
				vim.diagnostic.jump({ count = 1, float = true })
			end, "Next diagnostic")
			map("n", "[ge", function()
				vim.diagnostic.jump({ count = -1, float = true })
			end, "Previous diagnostic")
			map("n", "<leader>ge", vim.diagnostic.open_float, "Show diagnostic under cursor")

			map("n", "<leader>td", function()
				vim.diagnostic.enable(not vim.diagnostic.is_enabled())
			end, "Toggle diagnostics")

			-- Start/stop LSP on demand
			map("n", "<leader>ls", "<Cmd>LspStart<CR>", "Start LSP")
			map("n", "<leader>lS", "<Cmd>LspStop<CR>", "Stop LSP")
			map("n", "<leader>lr", "<Cmd>LspRestart<CR>", "Restart LSP")
		end,
	},
}
