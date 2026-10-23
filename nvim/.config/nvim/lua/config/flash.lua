local ns = vim.api.nvim_create_namespace('cursor_flash')

local M = {}

function M.at_cursor(width)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  vim.hl.range(0, ns, 'IncSearch', { row - 1, col }, { row - 1, col + width }, { timeout = 200 })
end

return M
