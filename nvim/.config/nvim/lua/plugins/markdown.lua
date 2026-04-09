return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    ft = { 'markdown' },
    opts = {
      code = {
        style = 'full',
        inline = false,
        border = 'thin',
        below = ' ',
        highlight_border = 'RenderMarkdownCode',
      },
      checkbox = {
        left_pad = 3,
      },
      win_options = {
        conceallevel = {
          rendered = 2,
        },
      },
    },
  },
}
