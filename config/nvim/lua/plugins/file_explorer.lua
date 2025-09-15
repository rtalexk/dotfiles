return {
  {
    'stevearc/oil.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      keymaps = {
        ['q'] = function()
          local win = vim.api.nvim_get_current_win()
          local buf = vim.api.nvim_get_current_buf()
          local buftype = vim.api.nvim_buf_get_option(buf, 'filetype')
          local is_floating = vim.api.nvim_win_get_config(win).relative ~= ''

          require('oil').close()

          -- Only close the window if it's an Oil buffer in a split (not floating) and there are multiple windows
          if buftype == 'oil' and not is_floating and vim.fn.winnr('$') > 1 then
            vim.cmd('close')
          end
        end,
      },
      columns = {
        'icon',
      },
      float = {
        get_win_title = function(winid)
          local cwd = vim.fn.getcwd()
          local buf = vim.api.nvim_win_get_buf(winid)
          local file_path = vim.api.nvim_buf_get_name(buf)

          local relative_path = file_path:sub(#cwd - 1)
          local parts = vim.split(relative_path, '/', { plain = true })

          local reversed = {}
          for i = #parts, 1, -1 do
            table.insert(reversed, parts[i])
          end

          return ' ' .. table.concat(reversed, '/') .. ' '
        end,
        max_width = 60,
        max_height = 45,
        override = function(defaults)
          -- See https://github.com/stevearc/oil.nvim/blob/685cdb4ffa74473d75a1b97451f8654ceeab0f4a/lua/oil/layout.lua#L129-L138
          -- defaults['col'] = vim.o.columns - defaults['width'] - 2
          return defaults
        end,
      },
      win_options = {
        signcolumn = 'yes:2',
      },
      view_options = {
        show_hidden = true,
        is_always_hidden = function(name)
          return vim.endswith(name, './') or name == '.git' or name == '..' or name == '.DS_Store'
        end,
      },
    },
    keys = {
      { '<leader>e', '<cmd>Oil --float<cr>', mode = { 'n' }, desc = 'Files' },
      { '<leader>fe', '<cmd>vsplit | Oil<cr>', mode = { 'n' }, desc = 'Files (VSplit)' },
    },
  },

  {
    'refractalize/oil-git-status.nvim',
    dependencies = {
      'stevearc/oil.nvim',
    },
    config = true,
  },

  -- Replace the netrw gx mapping as a workaround.
  -- Nvim 0.10 will implement a new API without netrw dependency, and as Oil replaces netrw, the gx
  -- mapping doesn't work anymore. This plugin fixes that.
  {
    'chrishrb/gx.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = true, -- default settings
    cmd = { 'Browse' },
    keys = { { 'gx', '<cmd>Browse<cr>', mode = { 'n', 'x' }, desc = 'Open in external app' } },
    init = function()
      vim.g.netrw_nogx = 1 -- disable netrw gx
    end,
  },
}
