-- Minimal init for headless plenary test runs
vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h"))

local function find_plugin(name)
	local base = vim.fn.stdpath("data")
	-- vim.pack (Neovim 0.12+)
	local pack = vim.fn.glob(base .. "/pack/*/{start,opt}/" .. name, false, true)
	if pack[1] then
		return pack[1]
	end
	-- lazy.nvim fallback
	local lazy = base .. "/lazy/" .. name
	if vim.fn.isdirectory(lazy) == 1 then
		return lazy
	end
end

local plenary_path = find_plugin("plenary.nvim")
if plenary_path then
	vim.opt.rtp:prepend(plenary_path)
end

local codediff_path = find_plugin("codediff.nvim")
if codediff_path then
	vim.opt.rtp:prepend(codediff_path)
end

require("plenary")
