if true then
  return {}
end

return {
  { -- File Explorer
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    cmd = 'Neotree',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
      'MunifTanjim/nui.nvim',
      -- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
    },
    keys = {
      {
        '<leader>fe',
        function()
          require('neo-tree.command').execute { toggle = true, dir = vim.loop.cwd(), reveal = true, position = 'right' }
        end,
        desc = 'File Explorer',
      },
      {
        '<leader>e',
        function()
          require('neo-tree.command').execute { toggle = true, dir = vim.loop.cwd(), reveal = true, position = 'float' }
        end,
        desc = 'File Explorer',
      },
      {
        '<leader>;',
        function()
          require('neo-tree.command').execute { toggle = true, dir = vim.loop.cwd(), reveal = true, source = 'git_status' }
        end,
        desc = 'Changed files',
      },
      {
        '<leader>,',
        function()
          require('neo-tree.command').execute { toggle = true, dir = vim.loop.cwd(), reveal = true, source = 'buffers' }
        end,
        desc = 'Buffers',
      },
    },
    opts = {
      close_if_las_window = true,
      popup_border_style = 'rounded',
      window = {
        position = 'float',
        popup = {
          size = function()
            return {
              width = 60,
              height = vim.o.lines - 10,
            }
          end,
        },
      },
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
        },
        follow_current_file = { enabled = true },
      },
      event_handlers = {
        {
          event = 'file_opened',
          handler = function()
            require('neo-tree.command').execute { action = 'close' }
          end,
        },
      },
      default_component_configs = {
        file_size = {
          enabled = false,
        },
        last_modified = {
          enabled = false,
        },
        created = {
          enabled = false,
        },
        type = {
          enabled = false,
        },
      },
    },
  },
}
