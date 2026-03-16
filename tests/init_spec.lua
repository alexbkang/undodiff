local undodiff = require("undodiff")

describe("setup", function()
	it("applies default opts", function()
		undodiff.setup({})
		assert.is_true(undodiff.opts.treesitter)
		assert.is_true(undodiff.opts.number)
		assert.is_false(undodiff.opts.relativenumber)
		assert.equals("no", undodiff.opts.signcolumn)
		assert.equals("]c", undodiff.opts.next_hunk)
		assert.equals("[c", undodiff.opts.prev_hunk)
	end)

	it("overrides defaults with user opts", function()
		undodiff.setup({
			treesitter = false,
			number = false,
			relativenumber = true,
			signcolumn = "yes",
			next_hunk = "]n",
			prev_hunk = "[n",
		})
		assert.is_false(undodiff.opts.treesitter)
		assert.is_false(undodiff.opts.number)
		assert.is_true(undodiff.opts.relativenumber)
		assert.equals("yes", undodiff.opts.signcolumn)
		assert.equals("]n", undodiff.opts.next_hunk)
		assert.equals("[n", undodiff.opts.prev_hunk)
	end)

	it("registers the UndoDiff user command", function()
		undodiff.setup({})
		local cmds = vim.api.nvim_get_commands({})
		assert.not_nil(cmds["UndoDiff"])
	end)
end)
