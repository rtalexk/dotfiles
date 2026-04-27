return {
  {
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      require('tokyonight').setup {
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
          hl['@markup.italic.markdown_inline'] = { fg = colors.purple, italic = true }
          hl['@markup.strong.asterisk.markdown_inline'] = { fg = colors.blue, bold = true }
          hl['@markup.strong.underscore.markdown_inline'] = { fg = colors.purple, bold = true }
        end,
      }
      vim.cmd.colorscheme 'tokyonight-moon'
      vim.opt.cursorline = true
      vim.opt.cursorlineopt = 'number'
      vim.cmd.hi 'Comment gui=none'
    end,
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
