return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    ft = { 'markdown' },
    opts = {
      bullet = {
        icons = { '-' },
      },
      dash = {
        width = 80,
      },
      heading = {
        width = 'block',
        right_pad = 2,
      },
      code = {
        style = 'full',
        width = 'block',
        right_pad = 2,
        inline = false,
        border = 'thin',
        below = ' ',
        highlight_border = 'RenderMarkdownCode',
      },
      checkbox = {
        left_pad = 3,
      },
      anti_conceal = {
        ignore = {
          code_background = true,
          code_border = true,
          code_language = true,
          head_background = true,
          head_border = true,
          head_icon = true,
          quote = true,
        },
      },
      win_options = {
        conceallevel = {
          rendered = 2,
        },
      },
    },
  },
}
