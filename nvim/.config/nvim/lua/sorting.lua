local M = {}

local function is_inside_object()
  local parsers = require 'nvim-treesitter.parsers'

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row, cursor_col = cursor[1] - 1, cursor[2]

  local parser = parsers.get_parser(bufnr)
  if not parser then
    return false
  end

  local tree = parser:parse()[1]
  local root = tree:root()

  local node = root:descendant_for_range(cursor_row, cursor_col, cursor_row, cursor_col)

  while node do
    local node_type = node:type()
    if node_type == 'object' or node_type == 'object_pattern' or node_type == 'dictionary' then
      return true
    end
    node = node:parent()
  end

  return false
end

local function get_tag_attributes_info()
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

  local is_inline = start_row == end_row

  return {
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
    is_inline = is_inline,
  }
end

local function select_and_sort_tag_attributes()
  local textobjects = require 'textobjects'
  textobjects.select_inside_tag_attributes()

  vim.cmd 'normal! V'
  vim.fn.feedkeys(':!sort\r', 'n')
end

function M.sort_intelligently()
  local tag_info = get_tag_attributes_info()
  local is_in_object = is_inside_object()

  local cursor_pos = vim.api.nvim_win_get_cursor(0)

  if tag_info then
    if tag_info.is_inline then
      local saved_row = cursor_pos[1]

      vim.cmd 'TSJToggle'
      vim.api.nvim_win_set_cursor(0, { saved_row, 0 })

      select_and_sort_tag_attributes()

      vim.cmd 'TSJToggle'
      vim.api.nvim_win_set_cursor(0, cursor_pos)
    else
      select_and_sort_tag_attributes()
      vim.schedule(function()
        vim.api.nvim_win_set_cursor(0, cursor_pos)
      end)
    end
  elseif is_in_object then
    vim.fn.feedkeys('vi{:!sort\r', 'n')
    vim.schedule(function()
      vim.api.nvim_win_set_cursor(0, cursor_pos)
    end)
  else
    vim.notify('Cursor is not inside an object or tag attributes', vim.log.levels.WARN)
  end
end

function M.setup()
  vim.api.nvim_create_user_command('Sort', function()
    M.sort_intelligently()
  end, { desc = 'Sort object keys or tag attributes' })

  vim.keymap.set('n', '<leader>cS', '<cmd>Sort<cr>', { desc = 'Sort object keys or attributes' })
end

return M
