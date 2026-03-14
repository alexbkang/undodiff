local M = {}
local session = require("undodiff.session")

function M.setup(opts)
	M.opts = vim.tbl_deep_extend("force", {
		treesitter = true,
		number = true,
		relativenumber = false,
		signcolumn = "no",
		diff_scroll_down = "<C-d>",
		diff_scroll_up = "<C-u>",
	}, opts or {})
	vim.api.nvim_create_user_command("UndoDiff", function()
		session.open(M.opts)
	end, { desc = "Open undodiff" })
end

return M
