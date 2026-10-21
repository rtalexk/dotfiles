-- render-markdown has no options for these table behaviours, so they patch
-- private methods of its table renderer and updater. Recheck after updates.

local row_fragments = setmetatable({}, { __mode = 'k' })

local function tint(line)
  return vim.tbl_map(function(chunk)
    local groups = vim.iter({ chunk[2] }):flatten():totable()
    groups[#groups + 1] = 'CursorLine'
    return { chunk[1], groups }
  end, line)
end

local function patch_table_rows()
  local Table = require('render-markdown.render.markdown.table')

  -- Wrapped cells of adjacent rows run together without a line between them
  local function separator(self)
    local border = self.config.border
    local parts = vim.tbl_map(function(col)
      return border[11]:rep(col.width)
    end, self.data.cols)
    return border[4] .. table.concat(parts, border[5]) .. border[6]
  end

  local function separated(self, row)
    local rows = self.data.rows
    return self.data.layout.valid and row.node.type ~= 'pipe_table_header' and row ~= rows[#rows]
  end

  local wrapped_row = Table.wrapped_row
  function Table:wrapped_row(row)
    local lines = wrapped_row(self, row)
    for _, line in ipairs(lines) do
      row_fragments[line] = true
    end
    if separated(self, row) then
      local line = self:line():extend(self.data.prefixes[row.node.start_row])
      lines[#lines + 1] = line:text(separator(self), self.config.row):get()
    end
    return lines
  end

  -- A fitted row is its own source line under pipe overlays, which a tint
  -- cannot reach, so the whole row is drawn again for when the cursor is on it
  local fitted_row = Table.row
  function Table:row(row)
    fitted_row(self, row)
    if self.data.layout.wrap then
      self.marks:insert(self.config, {
        conceal = true,
        start_row = row.node.start_row,
        start_col = 0,
        opts = { virt_text = tint(wrapped_row(self, row)[1]), virt_text_pos = 'overlay', priority = 65535 },
        hover_only = true,
      })
    end
    if separated(self, row) then
      local line = self:line():pad(self.data.layout.col):text(separator(self), self.config.row)
      self.marks:add(self.config, 'virtual_lines', row.node.start_row, 0, {
        virt_lines = { self:indent():line(true):extend(line):get() },
      })
    end
  end
end

-- A wrapped row is drawn as virtual lines over its concealed source line, so
-- upstream shows the raw source line while the cursor is on it. Neovim counts
-- a concealed cursor line as zero height and does not know where its row is
-- drawn, so the cursor is hidden and the window is scrolled here.
local function keep_hovered_rows_rendered()
  local Updater = require('render-markdown.core.ui').updater
  local env = require('render-markdown.lib.env')
  local drawn = setmetatable({}, { __mode = 'k' })
  local tinted = setmetatable({}, { __mode = 'k' })
  local cursored = setmetatable({}, { __mode = 'k' })
  local hovered = nil
  local last_drawn = nil
  local saved = nil
  local view_win = nil
  local split = nil
  local planned = nil
  local cursor_at = nil
  local on_fitted_row = false

  local function tint_fragments(lines)
    return vim.tbl_map(function(line)
      return row_fragments[line] and tint(line) or line
    end, lines)
  end

  local function pipes(raw)
    local found = {}
    local i = 1
    while i <= #raw do
      local char = raw:sub(i, i)
      if char == '\\' then
        i = i + 1
      elseif char == '|' then
        found[#found + 1] = i
      end
      i = i + 1
    end
    return found
  end

  local function explode(line)
    local chars = {}
    local cell = 0
    for _, chunk in ipairs(line) do
      for _, char in ipairs(vim.fn.split(chunk[1], '\\zs')) do
        local width = vim.fn.strdisplaywidth(char)
        chars[#chars + 1] = { char, chunk[2], cell = cell, width = width }
        cell = cell + width
      end
    end
    return chars
  end

  local function borders(chars, icon)
    return vim.tbl_filter(function(char)
      return char[1] == icon
    end, chars)
  end

  local function mark_cell(line, target)
    return vim.tbl_map(function(char)
      if char.cell <= target and target < char.cell + char.width then
        local groups = vim.iter({ char[2] }):flatten():totable()
        groups[#groups + 1] = 'RenderMarkdownFakeCursor'
        return { char[1], groups }
      end
      return { char[1], char[2] }
    end, explode(line))
  end

  -- The real cursor is hidden, so a block marks the cell under it. Cell text
  -- is placed by its width in the source, which concealed markup can offset.
  local function with_cursor(self, mark)
    local col = vim.api.nvim_win_get_cursor(self.win)[2] + 1
    local cached = cursored[mark]
    if cached and cached.col == col then
      return cached.lines
    end
    local lines = vim.list_slice(tinted[mark])
    local fragments = {}
    for i, line in ipairs(drawn[mark]) do
      if row_fragments[line] then
        fragments[#fragments + 1] = i
      end
    end
    local raw = vim.api.nvim_buf_get_lines(self.buf, mark.start_row, mark.start_row + 1, false)[1]
    local bars = pipes(raw)
    local icon = self.config.pipe_table.border[10]
    local padding = self.config.pipe_table.padding
    local cell = #vim.tbl_filter(function(bar)
      return bar < col
    end, bars)
    local index, target = fragments[1], nil
    if not index or #bars < 2 or #borders(explode(lines[index]), icon) ~= #bars then
      return lines
    elseif cell == 0 or cell == #bars or raw:sub(col, col) == '|' then
      local bar = math.min(math.max(raw:sub(col, col) == '|' and cell + 1 or cell, 1), #bars)
      target = borders(explode(lines[index]), icon)[bar].cell
    else
      local text = raw:sub(bars[cell] + 1, bars[cell + 1] - 1)
      local before = raw:sub(bars[cell] + 1, col - 1)
      local offset = math.max(vim.fn.strdisplaywidth(before) - #text:match('^%s*'), 0)
      for n, i in ipairs(fragments) do
        local chars = explode(lines[i])
        local edges = borders(chars, icon)
        local start = edges[cell].cell + 1 + padding
        local content = ''
        for _, char in ipairs(chars) do
          if char.cell >= start and char.cell < edges[cell + 1].cell then
            content = content .. char[1]
          end
        end
        local width = vim.fn.strdisplaywidth(vim.trim(content))
        index = i
        if offset < width or n == #fragments then
          target = start + math.min(offset, math.max(width - 1, 0))
          break
        end
        offset = offset - width - 1
      end
    end
    lines[index] = mark_cell(lines[index], target)
    cursored[mark] = { col = col, lines = lines }
    return lines
  end

  local hide = Updater.hide
  function Updater:hide(extmark, range)
    local mark = extmark:get()
    if mark.hover_only then
      local hidden = hide(self, extmark, range) or env.row.get(self.buf, self.win) ~= mark.start_row
      on_fitted_row = on_fitted_row or not hidden
      return hidden
    end
    if not mark.replace then
      return hide(self, extmark, range)
    end
    drawn[mark] = drawn[mark] or mark.replace
    mark.replace = drawn[mark]
    if env.row.get(self.buf, self.win) ~= mark.start_row then
      return hide(self, extmark, range)
    end
    mark.replace = nil
    local hidden = hide(self, extmark, range)
    tinted[mark] = tinted[mark] or tint_fragments(drawn[mark])
    mark.replace = tinted[mark]
    if not hidden then
      hovered = mark
      mark.replace = with_cursor(self, mark)
    end
    return hidden
  end

  -- Scrolloff counts buffer lines, and would undo the scroll made here
  local function enter(win, hide_cursor)
    if not saved then
      local scrolloff = vim.api.nvim_get_option_value('scrolloff', { scope = 'local', win = win })
      saved = { win = win, guicursor = vim.o.guicursor, scrolloff = scrolloff }
    end
    vim.api.nvim_set_hl(0, 'RenderMarkdownHiddenCursor', { blend = 100, nocombine = true })
    vim.api.nvim_set_hl(0, 'RenderMarkdownFakeCursor', { link = 'Cursor', default = true })
    vim.o.guicursor = hide_cursor and 'a:RenderMarkdownHiddenCursor' or saved.guicursor
    vim.api.nvim_set_option_value('scrolloff', 0, { scope = 'local', win = win })
  end

  local function leave()
    if saved then
      vim.o.guicursor = saved.guicursor
      if vim.api.nvim_win_is_valid(saved.win) then
        vim.api.nvim_set_option_value('scrolloff', saved.scrolloff, { scope = 'local', win = saved.win })
      end
      saved = nil
    end
  end

  local function concealed_rows(visible)
    local hidden = {}
    for _, mark in ipairs(visible) do
      if mark.opts.conceal_lines then
        local end_row = mark.opts.end_row or mark.start_row
        if end_row > mark.start_row and mark.opts.end_col == 0 then
          end_row = end_row - 1
        end
        for row = mark.start_row, end_row do
          hidden[row] = true
        end
      end
    end
    return hidden
  end

  local function sum(heights, from, to)
    local total = 0
    for i = from, to do
      total = total + heights[i]
    end
    return total
  end

  -- Upstream hangs a run of concealed rows above the line after it, and
  -- Neovim scrolls past all virtual lines of a line at once, so a long run
  -- cannot scroll. The rows before a split point hang below the line before
  -- the run instead, which turns the split into a scroll position in rows.
  -- Neovim cannot place a concealed cursor line, so the window is laid out
  -- here, with the hovered row next to where the cursor was on screen.
  local replacements = require('render-markdown.lib.replacements')
  local resolve = replacements.resolve
  function replacements.resolve(visible, line_count)
    if not hovered or not view_win then
      split = nil
      return resolve(visible, line_count)
    end
    local hidden = concealed_rows(visible)
    local above, below = hovered.start_row - 1, hovered.start_row + 1
    while above >= 0 and hidden[above] do
      above = above - 1
    end
    while below < line_count and hidden[below] do
      below = below + 1
    end
    local run = vim.tbl_filter(function(mark)
      return mark.replace and mark.start_row > above and mark.start_row < below
    end, visible)
    table.sort(run, function(a, b)
      return a.start_row < b.start_row
    end)
    local heights = vim.tbl_map(function(mark)
      return #mark.replace
    end, run)
    local index = {}
    for i, mark in ipairs(run) do
      index[mark.start_row] = i
    end
    local n = index[hovered.start_row]

    local win, buf = view_win, vim.api.nvim_win_get_buf(view_win)
    local height = vim.api.nvim_win_get_height(win)
    local own = (split and split.win == win and split.above == above) and split.lines or 0
    local function text_height(from, to, fill)
      local opts = { start_row = from, end_row = to, start_vcol = not fill and 0 or nil }
      return from > to and 0 or vim.api.nvim_win_text_height(win, opts).all
    end
    local function lead(row)
      return text_height(row, above) - own
    end

    local y = 0
    local was = cursor_at and cursor_at.win == win and cursor_at.buf == buf and cursor_at or nil
    if not was then
      local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
      if view.topline - 1 <= above then
        y = lead(view.topline - 1) + view.topfill + sum(heights, 1, n - 1)
      elseif split and split.win == win and split.above == above and n > split.kept then
        y = sum(heights, split.kept + 1, n - 1)
      end
    elseif index[was.row] then
      local i = index[was.row]
      y = i <= n and was.y + sum(heights, i, n - 1) or was.y - sum(heights, n, i - 1)
    elseif was.row <= above then
      y = was.y + lead(was.row) + sum(heights, 1, n - 1)
    elseif was.row >= below then
      y = was.y - sum(heights, n, #run) - text_height(below, was.row - 1)
    end
    y = math.max(0, math.min(y, height - heights[n]))

    local top, topfill, kept = nil, 0, 0
    local gap = y - sum(heights, 1, n - 1)
    if above >= 0 and gap >= 0 then
      for row = above, 0, -1 do
        local lines = lead(row)
        local fill = text_height(row, row, true) - text_height(row, row)
        if lines > gap then
          if lines + sum(heights, 1, n) <= height then
            top = row
          elseif row < above then
            top = row + 1
            topfill = text_height(row + 1, row + 1, true) - text_height(row + 1, row + 1)
          end
          break
        elseif lines + fill >= gap then
          top, topfill = row, gap - lines
          break
        elseif row == 0 then
          top, topfill = 0, fill
        end
      end
    end
    if top then
      y = lead(top) + topfill + sum(heights, 1, n - 1)
    else
      top = run[1].start_row
      while sum(heights, kept + 1, n - 1) > y do
        kept = kept + 1
      end
      y = sum(heights, kept + 1, n - 1)
    end
    planned = { topline = top + 1, topfill = topfill }
    cursor_at = { win = win, buf = buf, row = hovered.start_row, y = y }

    local lines = {}
    for i = 1, kept do
      vim.list_extend(lines, run[i].replace)
    end
    split = { win = win, above = above, kept = kept, lines = #lines }
    if kept == 0 then
      return resolve(visible, line_count)
    end
    local groups = resolve(
      vim.tbl_filter(function(mark)
        return not vim.list_contains(vim.list_slice(run, 1, kept), mark)
      end, visible),
      line_count
    )
    groups[#groups + 1] = { conceal = true, start_row = above, start_col = 0, opts = { virt_lines = lines, strict = false } }
    return groups
  end

  local display = Updater.display
  function Updater:display()
    hovered = nil
    on_fitted_row = false
    view_win = self.win == vim.api.nvim_get_current_win() and self.win or nil
    display(self)
    if view_win and (hovered or on_fitted_row) then
      enter(self.win, hovered ~= nil)
    else
      leave()
    end
    if planned then
      local view = planned
      vim.api.nvim_win_call(self.win, function()
        local current = vim.fn.winsaveview()
        if current.topline ~= view.topline or current.topfill ~= view.topfill then
          vim.fn.winrestview(view)
        end
      end)
      planned = nil
    elseif view_win then
      cursor_at = {
        win = self.win,
        buf = self.buf,
        row = vim.api.nvim_win_get_cursor(self.win)[1] - 1,
        y = vim.api.nvim_win_call(self.win, vim.fn.winline) - 1,
      }
    end
    -- Neovim leaves stale virtual lines on screen below concealed lines
    local drawing = hovered and hovered.replace
    if drawing ~= last_drawn then
      last_drawn = drawing
      vim.api.nvim__redraw({ win = self.win, valid = false })
    end
  end

  local clear = Updater.clear
  function Updater:clear()
    clear(self)
    leave()
  end
end

return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    ft = { 'markdown' },
    keys = {
      {
        '<leader>ut',
        function()
          local buf = vim.api.nvim_get_current_buf()
          local tables = require('render-markdown.state').get(buf).pipe_table
          tables.enabled = not tables.enabled
          require('render-markdown.core.ui').update(buf, vim.api.nvim_get_current_win(), 'UserCommand', true)
          if tables.enabled then
            vim.notify('Enabled table rendering', vim.log.levels.INFO)
          else
            vim.notify('Disabled table rendering', vim.log.levels.INFO)
          end
        end,
        ft = 'markdown',
        desc = 'Toggle table rendering',
      },
    },
    config = function(_, opts)
      require('render-markdown').setup(opts)
      patch_table_rows()
      keep_hovered_rows_rendered()
    end,
    opts = {
      change_events = { 'WinEnter' },
      bullet = {
        icons = { '-' },
      },
      dash = {
        width = 80,
      },
      heading = {
        width = 'block',
        right_pad = 2,
      },
      code = {
        style = 'full',
        width = 'block',
        right_pad = 2,
        inline = false,
        border = 'thin',
        below = ' ',
        highlight_border = 'RenderMarkdownCode',
      },
      checkbox = {
        left_pad = 3,
      },
      quote = {
        repeat_linebreak = true,
      },
      anti_conceal = {
        disabled_modes = { 'n', 'v', 'V', '\22' },
        ignore = {
          code_background = true,
          code_border = true,
          code_language = true,
          head_background = true,
          head_border = true,
          head_icon = true,
          quote = true,
        },
      },
      win_options = {
        conceallevel = {
          rendered = 2,
        },
        concealcursor = {
          rendered = 'nv',
        },
        showbreak = { default = '', rendered = '  ' },
        breakindent = { default = false, rendered = true },
        breakindentopt = { default = '', rendered = '' },
      },
    },
  },
}
