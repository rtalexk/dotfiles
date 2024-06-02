return {
  {
    'stevearc/oil.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      float = {
        max_width = 50,
        max_height = 80,
      },
    },
    keys = {
      { '<leader>e', '<cmd>Oil --float<cr>', mode = { 'n' }, desc = 'File explorer' },
    },
  },
}
