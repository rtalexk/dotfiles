vim.opt_local.wrap = true

-- Todo functionality for markdown files

local function get_todo_pattern_info(line)
  -- Match patterns like "- [ ]", "* [x]", "  - [ ]", etc.
  -- Must be at the start of the line (after optional whitespace) and followed by bullet + checkbox
  local indent, bullet, checkbox = line:match '^(%s*)([%-%*])%s+%[([%sx])%]'
  if indent and bullet and checkbox then
    return {
      indent = indent,
      bullet = bullet,
      checkbox = checkbox,
      is_complete = checkbox == 'x',
      prefix = indent .. bullet .. ' ',
      full_prefix = indent .. bullet .. ' [' .. checkbox .. '] ',
    }
  end
  return nil
end

-- target_state: true (complete), false (incomplete), nil (toggle)
local function set_todo_state(target_state)
  local line = vim.api.nvim_get_current_line()
  local info = get_todo_pattern_info(line)

  if info then
    -- If target_state is nil, toggle the current state
    local new_state = target_state
    if target_state == nil then
      new_state = not info.is_complete
    end

    local checkbox = new_state and 'x' or ' '
    local pattern = '^(' .. vim.pesc(info.indent) .. vim.pesc(info.bullet) .. '%s+)%[.%](.*)$'
    local prefix, content = line:match(pattern)

    if prefix and content then
      if new_state then
        -- Mark as complete: add strikethrough if not already present
        content = content:gsub('^%s*', '')
        if not content:match '^~~.*~~$' then
          content = ' ~~' .. content .. '~~'
        else
          content = ' ' .. content
        end
      else
        -- Mark as incomplete: remove strikethrough if present
        content = content:gsub('^%s*~~(.*)~~%s*$', ' %1')
        if not content:match '^%s' then
          content = ' ' .. content
        end
      end
      local new_line = prefix .. '[' .. checkbox .. ']' .. content
      vim.api.nvim_set_current_line(new_line)
      vim.cmd 'write'
    end
  else
    -- Only convert appropriate lines to todo
    local trimmed = line:match '^%s*(.-)%s*$' or ''
    if trimmed == '' then
      -- Empty line - create new todo
      vim.api.nvim_set_current_line '- [ ] '
      vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], 6 })
      vim.cmd 'write'
    else
      local indent = line:match '^(%s*)'
      local content = line:match '^%s*(.+)'

      -- Only convert if it's a regular list item (not headers, code blocks, etc.)
      local bullet_content = content:match '^[%-%*]%s+(.+)'
      if bullet_content then
        -- Already a list item, add checkbox
        local new_line = indent .. '- [ ] ' .. bullet_content
        vim.api.nvim_set_current_line(new_line)
        vim.cmd 'write'

        -- If we wanted to set it to complete after conversion, do it now
        if target_state == true then
          set_todo_state(true)
        end
      else
        -- no-op for non-todo, non-list lines
        return
      end
    end
  end
end

-- Toggle function is now just a wrapper
local function toggle_todo()
  set_todo_state(nil)
end

local function create_new_todo()
  local line = vim.api.nvim_get_current_line()
  local indent = line:match '^(%s*)'
  local cursor_pos = vim.api.nvim_win_get_cursor(0)

  vim.api.nvim_put({ indent .. '- [ ] ' }, 'l', true, true)
  vim.api.nvim_win_set_cursor(0, { cursor_pos[1] + 1, #indent + 6 })
  vim.cmd 'write'
end

local function remove_todo()
  local line = vim.api.nvim_get_current_line()
  local info = get_todo_pattern_info(line)

  if info then
    local pattern = '^(' .. vim.pesc(info.indent) .. vim.pesc(info.bullet) .. '%s+)%[.%]%s*'
    local new_line = line:gsub(pattern, '%1')
    vim.api.nvim_set_current_line(new_line)
    vim.cmd 'write'
  end
end

local bufnr = vim.api.nvim_get_current_buf()

vim.api.nvim_buf_create_user_command(bufnr, 'TodoToggle', function()
  toggle_todo()
end, { desc = 'Toggle todo item state' })

vim.api.nvim_buf_create_user_command(bufnr, 'TodoComplete', function()
  set_todo_state(true)
end, { desc = 'Mark todo item as complete' })

vim.api.nvim_buf_create_user_command(bufnr, 'TodoIncomplete', function()
  set_todo_state(false)
end, { desc = 'Mark todo item as incomplete' })

vim.api.nvim_buf_create_user_command(bufnr, 'TodoNew', function()
  create_new_todo()
end, { desc = 'Create new todo item' })

vim.api.nvim_buf_create_user_command(bufnr, 'TodoRemove', function()
  remove_todo()
end, { desc = 'Remove todo checkbox' })

vim.keymap.set('n', '<leader>tt', toggle_todo, { buffer = bufnr, desc = 'Toggle todo' })
vim.keymap.set('n', '<leader>tc', function()
  set_todo_state(true)
end, { buffer = bufnr, desc = 'Complete todo' })
vim.keymap.set('n', '<leader>ti', function()
  set_todo_state(false)
end, { buffer = bufnr, desc = 'Incomplete todo' })
vim.keymap.set('n', '<leader>tn', create_new_todo, { buffer = bufnr, desc = 'New todo' })
