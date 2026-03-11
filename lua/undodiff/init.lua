local M = {}

function M.setup(_opts)
	vim.api.nvim_create_user_command("UndoDiff", function()
		M.attach()
	end, { desc = "Open undotree with codediff side-by-side highlights" })
end

function M.attach()
	vim.cmd("packadd nvim.undotree")
	require("codediff").setup({})

	local curr_buf = vim.api.nvim_get_current_buf()
	local curr_win = vim.api.nvim_get_current_win()
	local orig_lines = vim.api.nvim_buf_get_lines(curr_buf, 0, -1, false)

	local tree_buf = vim.api.nvim_create_buf(false, true)
	require("undotree").open({ bufnr = tree_buf })

	-- find dimensions after undotree opens to get the resized curr_win
	local win_width = vim.api.nvim_win_get_width(curr_win)
	local win_height = vim.api.nvim_win_get_height(curr_win)

	-- floating scratch buffers to avoid modifying source buffer controlled by undotree
	local left_buf = vim.api.nvim_create_buf(false, true)
	local right_buf = vim.api.nvim_create_buf(false, true)

	local ft = vim.bo[curr_buf].filetype
	vim.bo[left_buf].filetype = ft
	vim.bo[right_buf].filetype = ft

	local float_opts = {
		relative = "win",
		win = curr_win,
		style = "minimal",
		border = "none",
		row = 0,
		col = 0,
		height = win_height,
	}

	local left_width = math.floor((win_width - 1) / 2)
	local right_width = win_width - left_width - 1

	local left_win =
		vim.api.nvim_open_win(left_buf, false, vim.tbl_extend("force", float_opts, { width = left_width, col = 0 }))
	local right_win = vim.api.nvim_open_win(
		right_buf,
		false,
		vim.tbl_extend("force", float_opts, { width = right_width, col = left_width + 1 })
	)
	-- for seprating left and right pane
	local sep_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(sep_buf, 0, -1, false, vim.fn["repeat"]({ "│" }, win_height))
	local sep_win =
		vim.api.nvim_open_win(sep_buf, false, vim.tbl_extend("force", float_opts, { width = 1, col = left_width }))

	-- sync left and right window scroll
	vim.wo[left_win].scrollbind = true
	vim.wo[right_win].scrollbind = true

	-- command to focus codediff
	vim.api.nvim_create_user_command("UndoDiffFocusDiff", function()
		if vim.api.nvim_win_is_valid(left_win) then
			vim.api.nvim_set_current_win(left_win)
		end
	end, { desc = "Focus the UndoDiff split view" })

	-- command to focus undotree
	vim.api.nvim_create_user_command("UndoDiffFocusTree", function()
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_get_buf(win) == tree_buf then
				vim.api.nvim_set_current_win(win)
				return
			end
		end
	end, { desc = "Focus the UndoDiff undo tree" })

	-- render with codediff
	local diff = require("codediff.core.diff")
	local core = require("codediff.ui.core")
	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = tree_buf,
		callback = function()
			if vim.api.nvim_buf_is_valid(curr_buf) then
				vim.bo[left_buf].modifiable = true
				vim.bo[right_buf].modifiable = true
				local new_lines = vim.api.nvim_buf_get_lines(curr_buf, 0, -1, false)
				vim.api.nvim_buf_set_lines(left_buf, 0, -1, false, orig_lines)
				vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, new_lines)
				core.render_diff(left_buf, right_buf, orig_lines, new_lines, diff.compute_diff(orig_lines, new_lines))
				vim.bo[left_buf].modifiable = false
				vim.bo[right_buf].modifiable = false
			end
		end,
	})

	-- teardown
	local cleaned_up = false -- so multiple win close doesn't trigger more than once
	local all_wins = { left_win, sep_win, right_win }
	local all_bufs = { left_buf, right_buf, sep_buf }
	local function cleanup()
		if cleaned_up then
			return
		end
		cleaned_up = true
		-- Close all windows
		for _, w in ipairs(all_wins) do
			if w and vim.api.nvim_win_is_valid(w) then
				vim.api.nvim_win_close(w, true)
			end
		end
		-- Delete all buffers
		for _, b in ipairs(all_bufs) do
			if b and vim.api.nvim_buf_is_valid(b) then
				pcall(vim.api.nvim_buf_delete, b, { force = true })
			end
		end
		-- close undotree
		pcall(require("undotree").open)
	end

	-- when user closes undotree
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = tree_buf,
		once = true,
		callback = cleanup,
	})

	-- when user closes one of the windows
	vim.api.nvim_create_autocmd("WinClosed", {
		callback = function(ev)
			local closed_win = tonumber(ev.match)
			for _, w in ipairs(all_wins) do
				if w == closed_win then
					cleanup()
					return
				end
			end
		end,
	})
end

return M
