local M = {}
local state = require("undodiff.state")

function M.close()
	local s = state.session
	state.session = nil
	if s == nil then
		return
	end

	if not s.confirmed and s.curr_buf and s.original_seq then
		vim.api.nvim_buf_call(s.curr_buf, function()
			vim.cmd("silent undo " .. s.original_seq)
		end)
	end
	if s.old_win and vim.api.nvim_win_is_valid(s.old_win) and s.curr_buf then
		vim.api.nvim_win_set_buf(s.old_win, s.curr_buf)
	end
	for _, bufnr in ipairs(s.buffers) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.b[bufnr].undodiff_active = nil
		end
	end
	if s.scratch_win and vim.api.nvim_win_is_valid(s.scratch_win) then
		vim.api.nvim_win_close(s.scratch_win, true)
	end
	if s.tree_win and vim.api.nvim_win_is_valid(s.tree_win) then
		vim.api.nvim_win_close(s.tree_win, true)
	end
end

function M.open(opts)
	local curr_buf = vim.api.nvim_get_current_buf()

	if state.is_active(curr_buf) then
		M.close()
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
	vim.cmd("rightbelow vsplit")
	local new_win = vim.api.nvim_get_current_win()
	local new_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[new_buf].bufhidden = "wipe"

	local old_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[old_buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(old_buf, 0, -1, false, old_lines)

	state.session = {
		buffers = { tree_buf, new_buf, old_buf },
		scratch_win = new_win,
		tree_win = tree_win,
		old_win = old_win,
		curr_buf = curr_buf,
		confirmed = false,
		original_seq = vim.fn.undotree(curr_buf).seq_cur,
	}
	state.set_active(state.session.buffers)

	vim.b[new_buf].lsp_disable = true
	vim.b[old_buf].lsp_disable = true
	vim.bo[new_buf].filetype = ft
	vim.bo[old_buf].filetype = ft
	if not opts.treesitter then
		vim.treesitter.stop(new_buf)
		vim.treesitter.stop(old_buf)
	end
	vim.wo[old_win].scrollbind = true
	vim.wo[new_win].scrollbind = true
	for _, win in ipairs({ old_win, new_win }) do
		vim.wo[win].number = opts.number
		vim.wo[win].relativenumber = opts.relativenumber
		vim.wo[win].signcolumn = opts.signcolumn
		vim.wo[win].winhighlight = "Normal:UndoDiffView"
	end

	require("codediff").setup({})
	require("undodiff.render").setup(tree_buf, curr_buf, old_buf, new_buf, old_lines, new_win)
	vim.api.nvim_win_set_buf(old_win, old_buf)
	vim.api.nvim_win_set_buf(new_win, new_buf)

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(tree_win),
		once = true,
		callback = function()
			M.close()
		end,
	})

	vim.keymap.set("n", "<CR>", function()
		if state.session then
			state.session.confirmed = true
		end
		vim.api.nvim_win_close(tree_win, true)
	end, { buffer = tree_buf, desc = "UndoDiff: confirm and close" })

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(tree_win, true)
	end, { buffer = tree_buf, desc = "UndoDiff: cancel and close" })

	vim.keymap.set("n", opts.diff_scroll_down, function()
		vim.api.nvim_win_call(new_win, function()
			vim.cmd("normal! \x04")
		end)
		vim.api.nvim_win_call(new_win, function()
			vim.cmd("syncbind")
		end)
	end, { buffer = tree_buf, desc = "UndoDiff: scroll diff down" })

	vim.keymap.set("n", opts.diff_scroll_up, function()
		vim.api.nvim_win_call(new_win, function()
			vim.cmd("normal! \x15")
		end)
		vim.api.nvim_win_call(new_win, function()
			vim.cmd("syncbind")
		end)
	end, { buffer = tree_buf, desc = "UndoDiff: scroll diff up" })

	vim.api.nvim_set_current_win(tree_win)
end

return M
