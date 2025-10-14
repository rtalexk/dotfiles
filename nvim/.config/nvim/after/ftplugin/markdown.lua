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

local function get_indent_level(line)
  local indent = line:match '^(%s*)'
  return #indent
end

local function is_continuation_line(line)
  -- A line is a continuation if it's not empty and doesn't start with a list marker at the beginning
  local trimmed = line:match '^%s*(.-)%s*$'
  if trimmed == '' then
    return false
  end

  -- Check if it's a list item (bullet point or numbered)
  local has_marker = line:match '^%s*[%-%*]%s+' or line:match '^%s*%d+%.%s+'
  return not has_marker
end

local function get_task_lines(start_line)
  local bufnr = vim.api.nvim_get_current_buf()
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local lines = { start_line }
  local start_info = get_todo_pattern_info(vim.api.nvim_buf_get_lines(bufnr, start_line - 1, start_line, false)[1])

  if not start_info then
    return lines
  end

  local base_indent = get_indent_level(vim.api.nvim_buf_get_lines(bufnr, start_line - 1, start_line, false)[1])

  -- Look for continuation lines (lines with deeper indentation or continuation lines)
  local current = start_line + 1
  while current <= total_lines do
    local line = vim.api.nvim_buf_get_lines(bufnr, current - 1, current, false)[1]
    local line_indent = get_indent_level(line)
    local line_info = get_todo_pattern_info(line)

    -- Empty line might be part of multi-line description
    if line:match '^%s*$' then
      -- Check if next line is continuation
      if current + 1 <= total_lines then
        local next_line = vim.api.nvim_buf_get_lines(bufnr, current, current + 1, false)[1]
        local next_indent = get_indent_level(next_line)
        if next_indent > base_indent and not get_todo_pattern_info(next_line) then
          table.insert(lines, current)
          current = current + 1
        else
          break
        end
      else
        break
      end

    -- Continuation line (indented more than base, not a new todo item)
    elseif line_indent > base_indent and is_continuation_line(line) then
      table.insert(lines, current)
      current = current + 1
    -- Child todo item (indented more, is a todo)
    elseif line_info and line_indent > base_indent then
      -- This is a child task, include it and its descendants
      local child_lines = get_task_lines(current)
      for _, child_line in ipairs(child_lines) do
        table.insert(lines, child_line)
      end
      current = current + #child_lines
    else
      -- Different task at same or lower indentation - stop
      break
    end
  end

  return lines
end

local function find_nearest_completed(start_line, indent_level)
  local bufnr = vim.api.nvim_get_current_buf()
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  local first_completed = nil
  local last_task_at_level = start_line
  local parent_end_line = total_lines

  -- If we're in a nested task (indented), find the parent boundary
  if indent_level > 0 then
    -- Look backwards to find parent task
    for i = start_line - 1, 1, -1 do
      local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
      local line_indent = get_indent_level(line)
      local line_info = get_todo_pattern_info(line)

      if line_info and line_indent < indent_level then
        -- Find where parent's scope ends
        for j = i + 1, total_lines do
          local next_line = vim.api.nvim_buf_get_lines(bufnr, j - 1, j, false)[1]

          -- Empty line ends parent scope
          if next_line:match '^%s*$' then
            parent_end_line = j - 1
            break
          end

          -- Header ends parent scope
          if next_line:match '^#' then
            parent_end_line = j - 1
            break
          end

          local next_indent = get_indent_level(next_line)
          local next_info = get_todo_pattern_info(next_line)

          -- Task at same or lower indentation than parent ends scope
          if next_info and next_indent <= line_indent then
            parent_end_line = j - 1
            break
          end
        end
        break
      end
    end
  end

  -- Search forward from the line after current task, up to parent boundary
  local search_end = parent_end_line
  for i = start_line + 1, search_end do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]

    -- Empty line indicates end of list
    -- TODO: Maybe allow one empty line in between tasks? Two empty lines definitely ends the list
    if line:match '^%s*$' then
      break
    end

    -- Header line indicates end of list
    if line:match '^#' then
      break
    end

    local line_indent = get_indent_level(line)
    local line_info = get_todo_pattern_info(line)

    -- If we find a task at same indentation level
    if line_info and line_indent == indent_level then
      -- Track this as last task at our level
      last_task_at_level = i

      if line_info.is_complete then -- Insert before first completed
        first_completed = i
        break
      end
    elseif line_info and line_indent < indent_level then
      -- Found task at lower indentation (parent level), end of our scope
      break
    elseif not line_info and line_indent <= indent_level then
      -- Non-task line at same or lower indentation, end of list
      break
    end
    -- Continue if line is at deeper indentation (child task/continuation)
  end

  if first_completed then
    return first_completed, 'before'
  else
    -- No completed items found
    if last_task_at_level == start_line then
      -- No other tasks found after current task, already at end of scope
      return nil, nil
    else
      -- Append after last task at this level
      -- Need to find the actual end including any child tasks
      local task_lines = get_task_lines(last_task_at_level)
      return task_lines[#task_lines], 'after'
    end
  end
end

local function move_task_block(task_lines, target_line, insert_mode)
  local bufnr = vim.api.nvim_get_current_buf()

  -- Get the lines to move
  local lines_to_move = {}
  for _, line_num in ipairs(task_lines) do
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    table.insert(lines_to_move, line)
  end

  -- Calculate adjusted target based on insert mode and task position
  local adjusted_target
  if insert_mode == 'before' then
    -- Insert before target_line
    adjusted_target = target_line - 1
    if task_lines[1] < target_line then
      -- Moving from above, account for deletion shifting lines up
      adjusted_target = target_line - #task_lines - 1
    end
  else -- insert_mode == 'after'
    -- Insert after target_line
    adjusted_target = target_line
    if task_lines[1] < target_line then
      -- Moving from above, account for deletion shifting lines up
      adjusted_target = target_line - #task_lines
    end
  end

  -- Delete original lines (from bottom to top to maintain line numbers)
  for i = #task_lines, 1, -1 do
    vim.api.nvim_buf_set_lines(bufnr, task_lines[i] - 1, task_lines[i], false, {})
  end

  -- Insert at target position
  vim.api.nvim_buf_set_lines(bufnr, adjusted_target, adjusted_target, false, lines_to_move)

  -- Return new position of the moved task
  return adjusted_target + 1
end

local set_todo_state

local function check_and_complete_parent(line_num, indent_level)
  local bufnr = vim.api.nvim_get_current_buf()

  -- Find parent task
  for i = line_num - 1, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    local line_indent = get_indent_level(line)
    local line_info = get_todo_pattern_info(line)

    if line_info and line_indent < indent_level then
      -- Found parent, check if all children are complete
      if line_info.is_complete then
        -- Parent already complete
        return
      end

      -- Get all children
      local parent_task_lines = get_task_lines(i)
      local all_children_complete = true

      for _, child_line_num in ipairs(parent_task_lines) do
        if child_line_num ~= i then
          local child_line = vim.api.nvim_buf_get_lines(bufnr, child_line_num - 1, child_line_num, false)[1]
          local child_info = get_todo_pattern_info(child_line)

          if child_info and not child_info.is_complete then
            all_children_complete = false
            break
          end
        end
      end

      if all_children_complete then
        -- Complete parent and move it
        vim.api.nvim_win_set_cursor(0, { i, 0 })
        set_todo_state(true)
      end

      return
    end
  end
end

-- target_state: true (complete), false (incomplete), nil (toggle)
set_todo_state = function(target_state)
  local current_line_num = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line()
  local info = get_todo_pattern_info(line)

  if info then
    -- If target_state is nil, toggle the current state
    local new_state = target_state
    if target_state == nil then
      new_state = not info.is_complete
    end

    -- Don't do anything if state is already what we want
    if new_state == info.is_complete then
      return
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

      -- If marking as complete, move task to nearest completed item
      if new_state then
        local indent_level = get_indent_level(line)
        local task_lines = get_task_lines(current_line_num)
        local target_line, insert_mode = find_nearest_completed(current_line_num, indent_level)

        -- Always move the task (either before first completed or after last incomplete)
        if target_line then
          local new_pos = move_task_block(task_lines, target_line, insert_mode)
          vim.api.nvim_win_set_cursor(0, { new_pos, 0 })
          vim.cmd 'write'

          -- Check if parent should be completed
          check_and_complete_parent(new_pos, indent_level)
        else
          -- Shouldn't happen, but check parent completion anyway
          check_and_complete_parent(current_line_num, indent_level)
        end
      end
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
