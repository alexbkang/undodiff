local M = {}

M.session = nil

function M.is_active(bufnr)
	return vim.b[bufnr].undodiff_active
end

function M.set_active(buffers)
	for _, bufnr in ipairs(buffers) do
		vim.b[bufnr].undodiff_active = true
	end
end

return M
