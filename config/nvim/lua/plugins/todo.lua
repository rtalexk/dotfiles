return {
  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      require('mini.ai').setup { n_lines = 500 }
      require('mini.surround').setup()

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
            if vim.g.have_nerd_font and filetype ~= '' then
              local ok, devicons = pcall(require, 'nvim-web-devicons')
              if ok then
                icon = devicons.get_icon_by_filetype(filetype) or ''
                if icon ~= '' then
                  icon = icon .. ' '
                end
              end
            end
            local fileinfo = icon .. filetype
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
