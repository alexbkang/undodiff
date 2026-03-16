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
	vim.bo[new_buf].modifiable = false

	local old_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[old_buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(old_buf, 0, -1, false, old_lines)
	vim.bo[old_buf].modifiable = false

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

	if opts.treesitter then
		local lang = vim.treesitter.language.get_lang(ft) or ft
		for _, buf in ipairs({ old_buf, new_buf }) do
			if not pcall(vim.treesitter.start, buf, lang) then
				vim.bo[buf].syntax = ft
			end
		end
	end
	for _, win in ipairs({ old_win, new_win }) do
		vim.wo[win].number = opts.number
		vim.wo[win].relativenumber = opts.relativenumber
		vim.wo[win].signcolumn = opts.signcolumn
		vim.wo[win].winhighlight = "Normal:UndoDiffView"
	end

	require("codediff").setup({})
	vim.api.nvim_win_set_buf(old_win, old_buf)
	vim.api.nvim_win_set_buf(new_win, new_buf)
	require("undodiff.render").setup(tree_buf, curr_buf, old_buf, new_buf, old_lines, old_win, new_win, tree_win)

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

	local function jump(target)
		pcall(vim.api.nvim_win_set_cursor, new_win, { target, 0 })
		vim.api.nvim_win_call(new_win, function()
			vim.cmd("normal! zz")
		end)
	end

	vim.keymap.set("n", opts.next_hunk, function()
		local s = state.session
		if not s or not s.diff_result or not s.diff_result.changes or #s.diff_result.changes == 0 then
			return
		end
		local changes = s.diff_result.changes
		local current_line = vim.api.nvim_win_get_cursor(new_win)[1]
		for _, change in ipairs(changes) do
			if change.modified.start_line > current_line then
				jump(change.modified.start_line)
				return
			end
		end
		jump(changes[1].modified.start_line)
	end, { buffer = tree_buf, desc = "UndoDiff: next hunk" })

	vim.keymap.set("n", opts.prev_hunk, function()
		local s = state.session
		if not s or not s.diff_result or not s.diff_result.changes or #s.diff_result.changes == 0 then
			return
		end
		local changes = s.diff_result.changes
		local current_line = vim.api.nvim_win_get_cursor(new_win)[1]
		for i = #changes, 1, -1 do
			if changes[i].modified.start_line < current_line then
				jump(changes[i].modified.start_line)
				return
			end
		end
		jump(changes[#changes].modified.start_line)
	end, { buffer = tree_buf, desc = "UndoDiff: prev hunk" })

	vim.api.nvim_set_current_win(tree_win)
end

return M
