return {
  {
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    init = function()
      -- Options: 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme 'tokyonight-moon'
      vim.opt.cursorline = true
      vim.opt.cursorlineopt = 'number'

      -- You can configure highlights by doing something like:
      vim.cmd.hi 'Comment gui=none'
    end,
    opts = {
      dim_inactive = true,
      transparent = true,
      terminal_colors = true,
      styles = {
        sidebars = 'transparent',
        floats = 'transparent',
      },
      on_highlights = function(hl, colors)
        hl.CursorLineNr = { fg = colors.orange }

        hl.LineNr = { fg = '#777d7d' }
        hl.LineNrAbove = { fg = '#777d7d' }
        hl.LineNrBelow = { fg = '#777d7d' }
        hl.Comment = { fg = '#777d7d' }
      end,
    },
  },

  -- {
  --   'oxfist/night-owl.nvim',
  --   lazy = false, -- make sure we load this during startup if it is your main colorscheme
  --   priority = 1000, -- make sure to load this before all the other start plugins
  --   name = 'night-owl',
  --   config = function()
  --     require('night-owl').setup {
  --       transparent_background = true,
  --     }
  --     vim.cmd.colorscheme 'night-owl'
  --   end,
  -- },
}
