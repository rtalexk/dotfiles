local M = {}

local stack = {}

local function visual_range()
  local from = vim.fn.getpos 'v'
  local to = vim.fn.getpos '.'

  local srow, scol = from[2] - 1, from[3] - 1
  local erow, ecol = to[2] - 1, to[3] - 1

  if srow > erow or (srow == erow and scol > ecol) then
    srow, scol, erow, ecol = erow, ecol, srow, scol
  end

  return { srow, scol, erow, ecol + 1 }
end

local function current(buf)
  local s = stack[buf]
  if s and #s > 0 then
    return s[#s]
  end
  return visual_range()
end

local function push(buf, range)
  stack[buf] = stack[buf] or {}
  table.insert(stack[buf], range)
end

local function select_range(buf, range)
  local srow, scol, erow, ecol = range[1], range[2], range[3], range[4]

  -- Treesitter end columns are exclusive; a 0 means the node stops at the
  -- start of erow, so the last selected byte lives on the line above.
  if ecol == 0 and erow > 0 then
    erow = erow - 1
    ecol = #(vim.api.nvim_buf_get_lines(buf, erow, erow + 1, false)[1] or '')
  end
  ecol = math.max(ecol, 1)

  if vim.fn.mode():match '[vV\22]' then
    vim.cmd 'normal! \27'
  end

  vim.fn.setpos('.', { 0, srow + 1, scol + 1, 0 })
  vim.cmd 'normal! v'
  vim.fn.setpos('.', { 0, erow + 1, ecol, 0 })
end

-- The highlighter only parses what it draws, so a selection command can run
-- before any tree exists for the buffer.
local function ensure_parsed(buf)
  local parser = vim.treesitter.get_parser(buf, nil, { error = false })
  if not parser then
    return nil
  end
  parser:parse(true)
  return parser
end

local function is_larger(range, cur)
  local starts_before = range[1] < cur[1] or (range[1] == cur[1] and range[2] < cur[2])
  local ends_after = range[3] > cur[3] or (range[3] == cur[3] and range[4] > cur[4])
  return starts_before or ends_after
end

function M.init()
  local buf = vim.api.nvim_get_current_buf()
  if not ensure_parsed(buf) then
    return
  end

  local node = vim.treesitter.get_node { bufnr = buf }
  if not node then
    return
  end

  local range = { node:range() }
  stack[buf] = { range }
  select_range(buf, range)
end

function M.node_incremental()
  local buf = vim.api.nvim_get_current_buf()
  if not ensure_parsed(buf) then
    return
  end

  local cur = current(buf)

  local node = vim.treesitter.get_node { bufnr = buf, pos = { cur[1], cur[2] } }
  while node do
    local range = { node:range() }
    if is_larger(range, cur) then
      push(buf, range)
      select_range(buf, range)
      return
    end
    node = node:parent()
  end
end

function M.scope_incremental()
  local buf = vim.api.nvim_get_current_buf()
  local parser = ensure_parsed(buf)
  if not parser then
    return
  end

  local cur = current(buf)
  local tree = parser:language_for_range { cur[1], cur[2], cur[3], cur[4] }
  local query = vim.treesitter.query.get(tree:lang(), 'locals')
  if not query then
    return M.node_incremental()
  end

  local scopes = {}
  for _, t in pairs(tree:trees()) do
    for id, node in query:iter_captures(t:root(), buf) do
      if query.captures[id] == 'local.scope' then
        scopes[node:id()] = true
      end
    end
  end

  local node = vim.treesitter.get_node { bufnr = buf, pos = { cur[1], cur[2] } }
  while node do
    local range = { node:range() }
    if scopes[node:id()] and is_larger(range, cur) then
      push(buf, range)
      select_range(buf, range)
      return
    end
    node = node:parent()
  end
end

function M.node_decremental()
  local buf = vim.api.nvim_get_current_buf()
  local s = stack[buf]
  if not s or #s < 2 then
    return
  end

  table.remove(s)
  select_range(buf, s[#s])
end

function M.attach(buf)
  local opts = { buffer = buf, silent = true }

  vim.keymap.set('n', 'gnn', M.init, vim.tbl_extend('force', opts, { desc = 'Init selection' }))
  vim.keymap.set('x', 'n', M.node_incremental, vim.tbl_extend('force', opts, { desc = 'Increment node' }))
  vim.keymap.set('x', 'N', M.scope_incremental, vim.tbl_extend('force', opts, { desc = 'Increment scope' }))
  vim.keymap.set('x', '<bs>', M.node_decremental, vim.tbl_extend('force', opts, { desc = 'Decrement node' }))
end

return M
