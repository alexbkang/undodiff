local undodiff = require("undodiff")

describe("setup", function()
	it("applies default opts", function()
		undodiff.setup({})
		assert.is_true(undodiff.opts.treesitter)
		assert.is_true(undodiff.opts.number)
		assert.is_false(undodiff.opts.relativenumber)
		assert.equals("no", undodiff.opts.signcolumn)
		assert.equals("<C-d>", undodiff.opts.diff_scroll_down)
		assert.equals("<C-u>", undodiff.opts.diff_scroll_up)
	end)

	it("overrides defaults with user opts", function()
		undodiff.setup({
			treesitter = false,
			number = false,
			relativenumber = true,
			signcolumn = "yes",
			diff_scroll_down = "<C-j>",
			diff_scroll_up = "<C-k>",
		})
		assert.is_false(undodiff.opts.treesitter)
		assert.is_false(undodiff.opts.number)
		assert.is_true(undodiff.opts.relativenumber)
		assert.equals("yes", undodiff.opts.signcolumn)
		assert.equals("<C-j>", undodiff.opts.diff_scroll_down)
		assert.equals("<C-k>", undodiff.opts.diff_scroll_up)
	end)

	it("registers the UndoDiff user command", function()
		undodiff.setup({})
		local cmds = vim.api.nvim_get_commands({})
		assert.not_nil(cmds["UndoDiff"])
	end)
end)
