local M = {}

function M.is_active(bufnr)
	return vim.b[bufnr].undodiff_active
end

function M.set_active(buffers)
	for _, bufnr in ipairs(buffers) do
		vim.b[bufnr].undodiff_active = true
	end
end

function M.clear(buffers, scratch_win)
	if M.old_win and vim.api.nvim_win_is_valid(M.old_win) and M.curr_buf then
		vim.api.nvim_win_set_buf(M.old_win, M.curr_buf)
		M.old_win = nil
		M.curr_buf = nil
	end
	for _, bufnr in ipairs(buffers) do
		vim.b[bufnr].undodiff_active = nil
	end
	if scratch_win and vim.api.nvim_win_is_valid(scratch_win) then
		vim.api.nvim_win_close(scratch_win, true)
	end
	if M.tree_win and vim.api.nvim_win_is_valid(M.tree_win) then
		vim.api.nvim_win_close(M.tree_win, true)
		M.tree_win = nil
	end
end

return M
