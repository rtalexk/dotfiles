-- Conform
-- Copilot
-- Nvim Cmp
-- Nvim Treesitter
-- Nx
-- Rest.nvim
-- TSJToggle
-- Typescript Tools

return {
  { -- Autoformat
    'stevearc/conform.nvim',
    lazy = false,
    keys = {
      {
        '<leader>ff',
        function()
          require('conform').format { async = true, lsp_fallback = true }
        end,
        mode = '',
        desc = 'Format buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_after_save = function(bufnr)
        -- Disable "format_after_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true, ruby = true }
        return {
          timeout_ms = 500,
          lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
        }
      end,
      formatters = {
        shfmt = {
          prepend_args = { '-i', '2' },
        },
      },
      formatters_by_ft = {
        lua = { 'stylua' },
        sh = { 'shfmt' },
        bash = { 'shfmt' },
        markdown = { 'prettier' },
        javascript = { 'prettier' },
        javascriptreact = { 'prettier' },
        typescript = { 'prettier' },
        typescriptreact = { 'prettier' },
        json = { 'prettier' },
        -- ruby = { 'standardrb' },
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
      },
    },
  },

  {
    'github/copilot.vim',
  },

  { -- Autocompletion
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      -- Snippet Engine & its associated nvim-cmp source
      {
        'L3MON4D3/LuaSnip',
        build = (function()
          -- Build Step is needed for regex support in snippets.
          -- This step is not supported in many windows environments.
          -- Remove the below condition to re-enable on windows.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          -- `friendly-snippets` contains a variety of premade snippets.
          --    See the README about individual language/framework/plugin snippets:
          --    https://github.com/rafamadriz/friendly-snippets
          -- {
          --   'rafamadriz/friendly-snippets',
          --   config = function()
          --     require('luasnip.loaders.from_vscode').lazy_load()
          --   end,
          -- },
        },
      },
      'onsails/lspkind.nvim',
      'saadparwaiz1/cmp_luasnip',

      -- Adds other completion capabilities.
      --  nvim-cmp does not ship with all sources by default. They are split
      --  into multiple repos for maintenance purposes.
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-path',
    },
    config = function()
      -- See `:help cmp`
      local cmp = require 'cmp'
      local luasnip = require 'luasnip'
      local lspkind = require 'lspkind'

      luasnip.config.setup {}

      cmp.setup {
        window = {
          completion = cmp.config.window.bordered { border = GlobalConfig.border },
          documentation = cmp.config.window.bordered { border = GlobalConfig.border },
        },
        formatting = {
          format = lspkind.cmp_format {
            mode = 'symbol_text',
            maxwidth = 50,
            ellipsis_char = '…',
            show_label_details = true,
          },
        },
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        completion = { completeopt = 'menu,menuone,noinsert' },

        -- TODO: Add lspkind.nvim or configure icons myself
        -- read `:help ins-completion`, it is really good!
        mapping = cmp.mapping.preset.insert {
          ['<C-n>'] = cmp.mapping.select_next_item(),
          ['<C-p>'] = cmp.mapping.select_prev_item(),
          ['<C-k>'] = cmp.mapping.scroll_docs(-4),
          ['<C-j>'] = cmp.mapping.scroll_docs(4),
          ['<C-y>'] = cmp.mapping.confirm { select = true },
          ['<C-c>'] = cmp.mapping.complete {},

          ['<C-l>'] = cmp.mapping(function()
            if luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            end
          end, { 'i', 's' }),
          ['<C-h>'] = cmp.mapping(function()
            if luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            end
          end, { 'i', 's' }),

          -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
          --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'path' },
        },
      }
    end,
  },

  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    opts = {
      ensure_installed = {
        'bash',
        'c',
        'html',
        'css',
        'json',
        'typescript',
        'tsx',
        'lua',
        'luadoc',
        'markdown',
        'vim',
        'vimdoc',
        'ruby',
        'javascript',
        'dockerfile',
        'gitignore',
      },
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = 'gnn', -- set to `false` to disable one of the mappings
          node_incremental = 'n',
          scope_incremental = 'N',
          node_decremental = '<bs>',
        },
      },
    },
    config = function(_, opts)
      -- [[ Configure Treesitter ]] See `:help nvim-treesitter`

      ---@diagnostic disable-next-line: missing-fields
      require('nvim-treesitter.configs').setup(opts)

      -- There are additional nvim-treesitter modules that you can use to interact
      -- with nvim-treesitter. You should go explore a few and see what interests you:
      --
      --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
      --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
      --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
    end,
  },

  -- Nx
  -- {
  --   {
  --     'Equilibris/nx.nvim',
  --
  --     dependencies = {
  --       'nvim-telescope/telescope.nvim',
  --     },
  --
  --     opts = {
  --       -- See below for config options
  --       nx_cmd_root = 'nx',
  --     },
  --
  --     -- Plugin will load when you use these keys
  --     keys = {
  --       { '<leader>nx', '<cmd>Telescope nx actions<CR>', desc = 'nx actions' },
  --     },
  --   },
  -- },

  -- Rest.nvim
  {
    'rest-nvim/rest.nvim',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      opts = function(_, opts)
        opts.ensure_installed = opts.ensure_installed or {}
        table.insert(opts.ensure_installed, 'http')
      end,
    },
    keys = {
      { '<leader>rr', '<cmd>Rest run<cr>', desc = 'Run Request' },
      { '<leader>rR', '<cmd>Rest open<cr>', desc = 'Open Result Panel' },
      { '<leader>rL', '<cmd>Rest last<cr>', desc = 'Run Last Request' },
    },
  },

  -- TSJToggle
  {
    'Wansmer/treesj',
    event = 'VeryLazy',
    keys = {
      { '<leader>cs', '<cmd>TSJToggle<cr>', desc = 'Toggle object lines' },
    },
    cmd = { 'TSJToggle', 'TSJJoin', 'TSJSplit' },
    opts = {
      use_default_keymaps = false,
    },
    langs = {
      javascript = {
        jsx_opening_element = {
          both = {
            -- Keep the default omit settings
            omit = { 'identifier', 'nested_identifier', 'member_expression' },
          },
          split = {
            -- Enable recursive splitting to handle nested attributes
            recursive = false,
            -- Control indentation for the closing bracket
            last_indent = 'inner', -- or 'normal'
          },
          join = {
            space_separator = true,
          },
        },
        jsx_self_closing_element = {
          both = {
            omit = { 'member_expression', 'identifier', 'nested_identifier', '>' },
            no_format_with = {},
          },
          split = {
            -- Customize which elements to omit during split
            omit = { 'identifier', 'nested_identifier', '/', '>', '/>' },
            last_indent = 'inner',
          },
        },
      },
    },
  },
  {
    'pmizio/typescript-tools.nvim',
    requires = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
    config = function()
      require('typescript-tools').setup {
        jsx_close_tag = {
          enable = true,
          filetypes = { 'javascriptreact', 'typescriptreact' },
        },
      }
    end,
  },
}
