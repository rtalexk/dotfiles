return {
  {
    'stevearc/oil.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      keymaps = {
        ['gq'] = 'actions.close',
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
}
