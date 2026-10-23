local ns = vim.api.nvim_create_namespace('cursor_flash')

local M = {}

-- Falls back to one character when the cursor is not on a keyword.
function M.at_cursor()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local rest = line:sub(col + 1)
  local after = vim.fn.matchstr(rest, [[^\k\+]])
  local start = col
  if after == '' then
    after = vim.fn.matchstr(rest, [[^.]])
  else
    start = col - #vim.fn.matchstr(line:sub(1, col), [[\k*$]])
  end
  local stop = col + #after
  vim.hl.range(0, ns, 'IncSearch', { row - 1, start }, { row - 1, stop }, { timeout = 200 })
end

return M
