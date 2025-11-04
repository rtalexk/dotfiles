local M = {}

local function get_tag_attributes_range()
  local parsers = require 'nvim-treesitter.parsers'

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row, cursor_col = cursor[1] - 1, cursor[2]

  local parser = parsers.get_parser(bufnr)
  if not parser then
    return nil
  end

  local tree = parser:parse()[1]
  local root = tree:root()

  local node = root:descendant_for_range(cursor_row, cursor_col, cursor_row, cursor_col)

  local function find_element_node(n)
    while n do
      local node_type = n:type()
      if
        node_type == 'jsx_element'
        or node_type == 'jsx_self_closing_element'
        or node_type == 'element'
        or node_type == 'self_closing_tag'
        or node_type == 'start_tag'
        or node_type == 'jsx_opening_element'
      then
        return n
      end
      n = n:parent()
    end
    return nil
  end

  local element = find_element_node(node)
  if not element then
    return nil
  end

  local first_attr = nil
  local last_attr = nil

  for child in element:iter_children() do
    local child_type = child:type()
    if child_type == 'jsx_attribute' or child_type == 'attribute' or child_type == 'jsx_spread_attribute' then
      if not first_attr then
        first_attr = child
      end
      last_attr = child
    end
  end

  if not first_attr or not last_attr then
    return nil
  end

  local start_row, start_col, _, _ = first_attr:range()
  local _, _, end_row, end_col = last_attr:range()

  return {
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
  }
end

function M.select_inside_tag_attributes()
  local range = get_tag_attributes_range()
  if not range then
    vim.notify('No tag attributes found', vim.log.levels.WARN)
    return
  end

  local mode = vim.fn.mode()

  -- Exit visual mode if already in it
  if mode == 'v' or mode == 'V' or mode == '\22' then
    vim.cmd 'normal! \27'
  end

  -- Move to start and enter visual mode
  vim.fn.setpos('.', { 0, range.start_row + 1, range.start_col + 1, 0 })
  vim.cmd 'normal! v'

  -- Move to end
  vim.fn.setpos('.', { 0, range.end_row + 1, range.end_col, 0 })
end

function M.select_around_tag_attributes()
  local range = get_tag_attributes_range()
  if not range then
    vim.notify('No tag attributes found', vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  local start_row, start_col = range.start_row, range.start_col
  local end_row, end_col = range.end_row, range.end_col

  local start_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
  while start_col > 0 and start_line:sub(start_col, start_col):match '%s' do
    start_col = start_col - 1
  end

  local end_line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1]
  while end_col <= #end_line and end_line:sub(end_col + 1, end_col + 1):match '%s' do
    end_col = end_col + 1
  end

  local mode = vim.fn.mode()

  -- Exit visual mode if already in it
  if mode == 'v' or mode == 'V' or mode == '\22' then
    vim.cmd 'normal! \27'
  end

  -- Move to start and enter visual mode
  vim.fn.setpos('.', { 0, start_row + 1, start_col + 1, 0 })
  vim.cmd 'normal! v'

  -- Move to end
  vim.fn.setpos('.', { 0, end_row + 1, end_col, 0 })
end

function M.setup()
  vim.keymap.set({ 'o', 'x' }, 'iT', function()
    M.select_inside_tag_attributes()
  end, { desc = 'Inside tag attributes' })

  vim.keymap.set({ 'o', 'x' }, 'aT', function()
    M.select_around_tag_attributes()
  end, { desc = 'Around tag attributes' })
end

return M
