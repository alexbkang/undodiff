local M = {}

function M.setup(tree_buf, curr_buf, old_buf, new_buf, old_lines, old_win, new_win, tree_win)
	local render = require("codediff.ui.view.render")
	local state = require("undodiff.state")

	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = tree_buf,
		callback = function()
			local new_lines = vim.api.nvim_buf_get_lines(curr_buf, 0, -1, false)
			vim.bo[new_buf].modifiable = true
			vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, new_lines)
			vim.bo[new_buf].modifiable = false

			local lines_diff =
				render.compute_and_render(old_buf, new_buf, old_lines, new_lines, true, true, old_win, new_win, true)

			if state.session then
				state.session.diff_result = lines_diff
			end

			if vim.api.nvim_win_is_valid(tree_win) then
				vim.api.nvim_set_current_win(tree_win)
			end
		end,
	})
end

return M
