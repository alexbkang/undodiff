local M = {}
local state = require("undodiff.state")

function M.setup(opts)
	M.opts = vim.tbl_deep_extend("force", {
		treesitter = true,
		number = true,
		signcolumn = "no",
	}, opts or {})
	vim.api.nvim_create_user_command("UndoDiff", function()
		M.attach()
	end, { desc = "Open undodiff" })
end

function M.attach()
	local curr_buf = vim.api.nvim_get_current_buf()

	if state.is_active(curr_buf) then
		state.clear(state.buffers, state.scratch_win)
		return
	end

	local ft = vim.bo[curr_buf].filetype
	local old_lines = vim.api.nvim_buf_get_lines(curr_buf, 0, -1, false)
	local old_win = vim.api.nvim_get_current_win()

	vim.cmd("packadd nvim.undotree")
	local tree_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[tree_buf].bufhidden = "wipe"
	require("undotree").open({ bufnr = tree_buf })
	local tree_win = vim.api.nvim_get_current_win()
	vim.wo[tree_win].winhighlight = "Normal:UndoDiffTree"

	vim.api.nvim_set_current_win(old_win)
	vim.cmd("vsplit")
	local new_win = vim.api.nvim_get_current_win()
	local new_buf = vim.api.nvim_create_buf(false, true)

	local old_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(old_buf, 0, -1, false, old_lines)

	state.buffers = { tree_buf, new_buf, old_buf }
	state.scratch_win = new_win
	state.tree_win = tree_win
	state.old_win = old_win
	state.curr_buf = curr_buf
	state.confirmed = false
	state.original_seq = vim.fn.undotree(curr_buf).seq_cur
	state.set_active(state.buffers)

	vim.b[new_buf].lsp_disable = true
	vim.b[old_buf].lsp_disable = true
	vim.bo[new_buf].filetype = ft
	vim.bo[old_buf].filetype = ft
	if not M.opts.treesitter then
		vim.treesitter.stop(new_buf)
		vim.treesitter.stop(old_buf)
	end
	vim.wo[old_win].scrollbind = true
	vim.wo[new_win].scrollbind = true
	for _, win in ipairs({ old_win, new_win }) do
		vim.wo[win].number = M.opts.number
		vim.wo[win].signcolumn = M.opts.signcolumn
		vim.wo[win].winhighlight = "Normal:UndoDiffView"
	end

	local function sync_cursor(from_win, to_win)
		local cursor = vim.api.nvim_win_get_cursor(from_win)
		if vim.api.nvim_win_is_valid(to_win) then
			vim.api.nvim_win_set_cursor(to_win, cursor)
		end
	end

	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = old_buf,
		callback = function() sync_cursor(old_win, new_win) end,
	})
	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = new_buf,
		callback = function() sync_cursor(new_win, old_win) end,
	})

	require("codediff").setup({})
	require("undodiff.render").setup(tree_buf, curr_buf, old_buf, new_buf, old_lines)
	vim.api.nvim_win_set_buf(old_win, old_buf)
	vim.api.nvim_win_set_buf(new_win, new_buf)

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(tree_win),
		once = true,
		callback = function()
			state.clear(state.buffers, state.scratch_win)
		end,
	})

	vim.keymap.set("n", "<CR>", function()
		state.confirmed = true
		vim.api.nvim_win_close(tree_win, true)
	end, { buffer = tree_buf, desc = "UndoDiff: confirm and close" })

	vim.api.nvim_set_current_win(tree_win)
end

return M
