local session = require("undodiff.session")
local state = require("undodiff.state")

local function make_buf_with_undo_history()
	local buf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
	vim.cmd("normal! ioriginal\x1b")
	local original_seq = vim.fn.undotree(buf).seq_cur
	vim.cmd("normal! ggVGcmodified\x1b")
	local modified_seq = vim.fn.undotree(buf).seq_cur
	return buf, original_seq, modified_seq
end

local function reset_state()
	local s = state.session
	if s then
		for _, buf in ipairs(s.buffers or {}) do
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
		if s.scratch_win and vim.api.nvim_win_is_valid(s.scratch_win) then
			vim.api.nvim_win_close(s.scratch_win, true)
		end
		if s.tree_win and vim.api.nvim_win_is_valid(s.tree_win) then
			vim.api.nvim_win_close(s.tree_win, true)
		end
	end
	state.session = nil
end

describe("session.close", function()
	before_each(reset_state)
	after_each(reset_state)

	it("clears active flag from all buffers", function()
		local buf = vim.api.nvim_create_buf(false, true)
		state.session = { buffers = { buf } }
		state.set_active({ buf })
		session.close()
		assert.is_nil(state.is_active(buf))
		vim.api.nvim_buf_delete(buf, { force = true })
	end)

	it("closes scratch_win if valid", function()
		local scratch_buf = vim.api.nvim_create_buf(false, true)
		local scratch_win = vim.api.nvim_open_win(scratch_buf, false, {
			relative = "editor",
			width = 1,
			height = 1,
			row = 0,
			col = 0,
		})
		state.session = { buffers = {}, scratch_win = scratch_win }
		session.close()
		assert.is_false(vim.api.nvim_win_is_valid(scratch_win))
		vim.api.nvim_buf_delete(scratch_buf, { force = true })
	end)

	it("closes tree_win if valid", function()
		local tree_buf = vim.api.nvim_create_buf(false, true)
		local tree_win = vim.api.nvim_open_win(tree_buf, false, {
			relative = "editor",
			width = 1,
			height = 1,
			row = 0,
			col = 0,
		})
		state.session = { buffers = {}, tree_win = tree_win }
		session.close()
		assert.is_false(vim.api.nvim_win_is_valid(tree_win))
		assert.is_nil(state.session)
		vim.api.nvim_buf_delete(tree_buf, { force = true })
	end)

	it("clears session after close", function()
		state.session = { buffers = {}, confirmed = true, original_seq = 5 }
		session.close()
		assert.is_nil(state.session)
	end)

	it("restores curr_buf into old_win and clears state", function()
		local buf = vim.api.nvim_create_buf(false, true)
		local other_buf = vim.api.nvim_create_buf(false, true)
		local win = vim.api.nvim_open_win(other_buf, false, {
			relative = "editor",
			width = 1,
			height = 1,
			row = 0,
			col = 0,
		})
		state.session = { buffers = {}, old_win = win, curr_buf = buf }
		session.close()
		assert.equals(buf, vim.api.nvim_win_get_buf(win))
		assert.is_nil(state.session)
		vim.api.nvim_win_close(win, true)
		vim.api.nvim_buf_delete(buf, { force = true })
		vim.api.nvim_buf_delete(other_buf, { force = true })
	end)

	it("undoes to original_seq when not confirmed", function()
		local buf, original_seq = make_buf_with_undo_history()
		state.session = { buffers = {}, curr_buf = buf, original_seq = original_seq, confirmed = false }
		session.close()
		assert.equals(original_seq, vim.fn.undotree(buf).seq_cur)
		vim.api.nvim_buf_delete(buf, { force = true })
	end)

	it("skips undo when confirmed", function()
		local buf, original_seq, modified_seq = make_buf_with_undo_history()
		state.session = { buffers = {}, curr_buf = buf, original_seq = original_seq, confirmed = true }
		session.close()
		assert.equals(modified_seq, vim.fn.undotree(buf).seq_cur)
		vim.api.nvim_buf_delete(buf, { force = true })
	end)
end)

local has_codediff = pcall(require, "codediff")
local has_undotree = pcall(function()
	vim.cmd("packadd nvim.undotree")
end)

describe("session.open", function()
	before_each(function()
		require("undodiff").setup({})
		reset_state()
	end)
	after_each(reset_state)

	if not has_codediff or not has_undotree then
		it("skipped: codediff or nvim.undotree not available", function()
			assert.is_true(false)
		end)
		return
	end

	it("populates state after open", function()
		local buf = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_set_current_buf(buf)
		session.open(require("undodiff").opts)
		local s = state.session
		assert.not_nil(s)
		assert.not_nil(s.curr_buf)
		assert.not_nil(s.tree_win)
		assert.not_nil(s.scratch_win)
		assert.not_nil(s.old_win)
		assert.is_false(s.confirmed)
		assert.not_nil(s.original_seq)
	end)

	it("marks scratch buffers as active", function()
		local buf = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_set_current_buf(buf)
		session.open(require("undodiff").opts)
		for _, b in ipairs(state.session.buffers) do
			assert.is_true(state.is_active(b))
		end
	end)

	it("toggles off when open called on active buffer", function()
		local buf = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_set_current_buf(buf)
		session.open(require("undodiff").opts)
		vim.api.nvim_set_current_win(state.session.tree_win)
		session.open(require("undodiff").opts)
		assert.is_nil(state.session)
	end)

	it("<CR> confirms and closes tree_win", function()
		local buf = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_set_current_buf(buf)
		session.open(require("undodiff").opts)
		local tree_win = state.session.tree_win
		vim.api.nvim_set_current_win(tree_win)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)
		assert.is_false(vim.api.nvim_win_is_valid(tree_win))
	end)

	it("q cancels and closes tree_win", function()
		local buf = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_set_current_buf(buf)
		session.open(require("undodiff").opts)
		local tree_win = state.session.tree_win
		vim.api.nvim_set_current_win(tree_win)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("q", true, false, true), "x", false)
		assert.is_false(vim.api.nvim_win_is_valid(tree_win))
	end)
end)
