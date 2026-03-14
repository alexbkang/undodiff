if vim.g.loaded_undodiff then
	return
end
vim.g.loaded_undodiff = true

require("undodiff").setup()
