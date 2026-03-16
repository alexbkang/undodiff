local M = {}
local session = require("undodiff.session")

function M.setup(opts)
	M.opts = vim.tbl_deep_extend("force", {
		treesitter = true,
		number = true,
		relativenumber = false,
		signcolumn = "no",
		next_hunk = "]c",
		prev_hunk = "[c",
	}, opts or {})
	vim.api.nvim_create_user_command("UndoDiff", function()
		session.open(M.opts)
	end, { desc = "Open undodiff" })
end

return M
