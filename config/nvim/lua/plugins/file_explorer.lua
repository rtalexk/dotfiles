--
return {
  {
    'stevearc/oil.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      keymaps = {
        ['q'] = 'actions.close',
      },
      columns = {
        'icon',
      },
      float = {
        max_width = 50,
        max_height = 80,
      },
      view_options = {
        show_hidden = true,
        is_always_hidden = function(name)
          return vim.startswith(name, '.git') or name == '../' or name == './' or name == '.DS_Store'
        end,
      },
    },
    keys = {
      { '<leader>e', '<cmd>Oil --float<cr>', mode = { 'n' }, desc = 'File explorer' },
    },
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
