return {
  {
    'nvim-treesitter/nvim-treesitter',
    optional = true,
    opts = function()
      require('sorting').setup()
    end,
  },
}
