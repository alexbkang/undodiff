local M = {}

function M.setup(_opts)
  vim.api.nvim_create_user_command('UndoDiff', function()
    M.attach()
  end, { desc = 'Open undotree with codediff side-by-side highlights' })
end

function M.attach()
  vim.cmd('packadd nvim.undotree')
  require("codediff").setup({})
  
  local buf = vim.api.nvim_get_current_buf()
  local curr_win = vim.api.nvim_get_current_win()
  local orig_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local tree_buf = vim.api.nvim_create_buf(false, true)
  require('undotree').open({ bufnr = tree_buf })
  
  -- find dimensions after undotree opens 
  local win_width = vim.api.nvim_win_get_width(curr_win)
  local win_height = vim.api.nvim_win_get_height(curr_win)
  
  -- floating scratch buffers to avoid modifying source buffer controlled by undotree
  local ft = vim.bo[buf].filetype
  local left_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[left_buf].filetype = ft
  local right_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[right_buf].filetype = ft
  local half = math.floor(win_width / 2)
  local float_opts = {
    relative = "win",
    win = curr_win,
    style = "minimal",
    row = 0,
    col = 0,
    height = win_height,
  }
  local left_win = vim.api.nvim_open_win(
    left_buf,
    false,
    vim.tbl_extend("force", float_opts, { width = half })
  )
  local right_win = vim.api.nvim_open_win(
    right_buf,
    false,
    vim.tbl_extend("force", float_opts, { width = win_width - half, col = half })
  )
  
  local diff = require('codediff.core.diff')
  local core = require('codediff.ui.core')

   local function render(old_lines, new_lines)
    vim.api.nvim_buf_set_lines(left_buf, 0, -1, false, old_lines)
    vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, new_lines)
    core.render_diff(left_buf, right_buf, old_lines, new_lines, diff.compute_diff(old_lines, new_lines))
  end

  -- render with codediff
  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = tree_buf,
    callback = function()
      if vim.api.nvim_buf_is_valid(buf) then
        render(orig_lines, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      end
    end,
  })

  -- teardown 
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = tree_buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(left_win) then vim.api.nvim_win_close(left_win, true) end
      pcall(vim.api.nvim_buf_delete, left_buf, { force = true })
      if vim.api.nvim_win_is_valid(right_win) then vim.api.nvim_win_close(right_win, true) end
      pcall(vim.api.nvim_buf_delete, right_buf, { force = true })
    end,
  })
end

return M
