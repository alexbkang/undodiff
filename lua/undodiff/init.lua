local M = {}
local state = require("undodiff.state")

function M.setup(_opts)
	vim.api.nvim_create_user_command("UndoDiff", function()
		M.attach()
	end, { desc = "Open undodiff" })
end

function M.attach()
	local old_buf = vim.api.nvim_get_current_buf()

	-- if already open, close
	if state.is_active(old_buf) then
		state.clear(state.buffers, state.scratch_win)
		require("undotree").open()
		return
	end

	-- save the state of file buffer
	local ft = vim.bo[old_buf].filetype
	local old_lines = vim.api.nvim_buf_get_lines(old_buf, 0, -1, false)
	local old_win = vim.api.nvim_get_current_win()

	-- open undotree
	vim.cmd("packadd nvim.undotree")
	local tree_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[tree_buf].bufhidden = "wipe"
	require("undotree").open({ bufnr = tree_buf })
	local tree_win = vim.api.nvim_get_current_win()

	-- split the file windowto old_win & new_win
	vim.api.nvim_set_current_win(old_win)
	vim.cmd("vsplit")
	local new_win = vim.api.nvim_get_current_win()
	local new_buf = vim.api.nvim_create_buf(false, true)

	-- save in state for cleanup
	state.buffers = { old_buf, tree_buf, new_buf }
	state.scratch_win = new_win
	state.set_active(state.buffers)

	-- prep for diffview
	vim.bo[new_buf].filetype = ft
	vim.wo[old_win].scrollbind = true
	vim.wo[new_win].scrollbind = true

	-- render diff
	require("codediff").setup({})
	require("undodiff.render").setup(tree_buf, old_buf, new_buf, old_lines)
	vim.api.nvim_win_set_buf(old_win, old_buf)
	vim.api.nvim_win_set_buf(new_win, new_buf)

	-- focus back to undodiff split
	vim.api.nvim_set_current_win(tree_win)
end

return M
