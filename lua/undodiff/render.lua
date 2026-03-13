local M = {}

function M.setup(tree_buf, old_buf, new_buf, old_lines)
	local diff = require("codediff.core.diff")
	local core = require("codediff.ui.core")

	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = tree_buf,
		callback = function()
			local new_lines = vim.api.nvim_buf_get_lines(old_buf, 0, -1, false)
			vim.bo[new_buf].modifiable = true
			vim.api.nvim_buf_set_lines(old_buf, 0, -1, false, old_lines)
			vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, new_lines)
			core.render_diff(old_buf, new_buf, old_lines, new_lines, diff.compute_diff(old_lines, new_lines))
			vim.bo[new_buf].modifiable = false
		end,
	})
end

return M
