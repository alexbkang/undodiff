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
	for _, bufnr in ipairs(buffers) do
		vim.b[bufnr].undodiff_active = nil
	end
	if scratch_win and vim.api.nvim_win_is_valid(scratch_win) then
		vim.api.nvim_win_close(scratch_win, true)
	end
end

return M
