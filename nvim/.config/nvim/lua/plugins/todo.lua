return {
  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      require('mini.ai').setup { n_lines = 500 }
      local MiniSurround = require 'mini.surround'
      MiniSurround.setup()

      -- mini.surround moves the cursor to a delimiter after `sa`/`sd`. These
      -- helpers keep it on the char it started on: plant an extmark there, run
      -- the operation, then move the cursor to wherever that char ended up.
      local surround_ns = vim.api.nvim_create_namespace 'surround_keep_cursor'

      local function clamp_col(row0, col)
        local line = vim.api.nvim_buf_get_lines(0, row0, row0 + 1, true)[1]
        return math.min(col, math.max(#line - 1, 0))
      end

      local function keep_cursor_at(row0, col, action)
        local id = vim.api.nvim_buf_set_extmark(0, surround_ns, row0, col, { right_gravity = true })
        local ok, res = pcall(action)
        local mark = vim.api.nvim_buf_get_extmark_by_id(0, surround_ns, id, {})
        vim.api.nvim_buf_del_extmark(0, surround_ns, id)
        if mark[1] then
          vim.api.nvim_win_set_cursor(0, { mark[1] + 1, clamp_col(mark[1], mark[2]) })
        end
        if not ok then
          error(res)
        end
        return res
      end

      -- `sa`: keep cursor at the visual selection end (the '> mark) instead of
      -- jumping to the opening delimiter. `:<C-u>` (not `<Cmd>`) leaves visual
      -- mode so the '< / '> marks are set before MiniSurround.add reads them.
      _G.SurroundKeepCursor = function()
        local e = vim.api.nvim_buf_get_mark(0, '>')
        keep_cursor_at(e[1] - 1, clamp_col(e[1] - 1, e[2]), function()
          MiniSurround.add 'visual'
        end)
      end
      vim.keymap.set('x', 'sa', ':<C-u>lua SurroundKeepCursor()<CR>', { silent = true, desc = 'Surround add (keep cursor at selection end)' })

      -- `sd`: keep cursor in place instead of jumping to the start of the
      -- deleted surrounding. `operatorfunc` resolves this dynamically, so
      -- wrapping the function also covers `sdl`/`sdn` and dot-repeat.
      local orig_delete = MiniSurround.delete
      MiniSurround.delete = function(...)
        local pos = vim.api.nvim_win_get_cursor(0)
        local args = { ... }
        return keep_cursor_at(pos[1] - 1, pos[2], function()
          return orig_delete(table.unpack(args))
        end)
      end

      local statusline = require 'mini.statusline'
      statusline.setup {
        use_icons = vim.g.have_nerd_font,
        content = {
          active = function()
            local _, mode_hl = statusline.section_mode { trunc_width = 120 }
            -- Custom filename - project folder + relative path
            local filepath = vim.fn.expand '%:.'
            local filename
            if filepath == '' then
              filename = '[No Name]'
            else
              local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
              filename = project_name .. '/' .. filepath
            end
            -- Custom fileinfo - only filetype with icon
            local filetype = vim.bo.filetype
            local icon = ''

            -- Filetype display rules: true = hide, string = replace
            local filetype_rules = {
              javascript = true,
              typescript = true,
              typescriptreact = true,
              javascriptreact = true,
              python = 'py',
              markdown = 'md',
            }

            if vim.g.have_nerd_font and filetype ~= '' then
              local ok, devicons = pcall(require, 'nvim-web-devicons')
              if ok then
                icon = devicons.get_icon_by_filetype(filetype) or ''
                if icon ~= '' then
                  icon = icon .. ' '
                end
              end
            end

            local rule = filetype_rules[filetype]
            local display_filetype
            if rule == true and icon ~= '' then
              display_filetype = ''
            elseif type(rule) == 'string' then
              display_filetype = ' ' .. rule
            else
              display_filetype = ' ' .. filetype
            end
            local fileinfo = icon .. display_filetype
            local location = statusline.section_location { trunc_width = 75 }

            -- Custom mode display (N, V, I only)
            local mode_map = {
              ['Normal'] = 'N',
              ['Insert'] = 'I',
              ['Visual'] = 'V',
              ['V-Line'] = 'V',
              ['V-Block'] = 'V',
              ['Select'] = 'S',
              ['S-Line'] = 'S',
              ['S-Block'] = 'S',
              ['Replace'] = 'R',
              ['Command'] = 'C',
              ['Confirm'] = '?',
              ['More'] = 'M',
              ['Terminal'] = 'T',
            }

            local mode_name = vim.fn.mode(1):gsub('^%l', string.upper):gsub('v', 'V')
            local short_mode = mode_map[mode_name] or mode_map[vim.fn.mode()] or mode_name:sub(1, 1)

            return statusline.combine_groups {
              { hl = mode_hl, strings = { short_mode } },
              '%<', -- Mark general truncate point
              { hl = 'MiniStatuslineFilename', strings = { filename } },
              '%=', -- End left alignment
              { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
              { hl = mode_hl, strings = { location } },
            }
          end,
          inactive = function()
            -- Custom filename - project folder + relative path for inactive windows too
            local filepath = vim.fn.expand '%:.'
            local filename
            if filepath == '' then
              filename = '[No Name]'
            else
              local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
              filename = project_name .. '/' .. filepath
            end

            return statusline.combine_groups {
              { hl = 'MiniStatuslineInactive', strings = { filename } },
            }
          end,
        },
      }
    end,
  },
}
