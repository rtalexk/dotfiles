-- Comment
-- Todo Comments
-- GitSigns
-- Harpoon2
-- Leap
-- mini.bufremove
-- mini.pairs
-- Telescope
-- Tokyonight
-- WhichKey
-- Vim Illuminate
-- Vim Sleuth
-- Vim Tmux Navigator

return {
  { -- "gc" to comment visual regions/lines
    'numToStr/Comment.nvim',
    opts = {},
  },

  { -- Highlight todo, notes, etc in comments
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { signs = false },
  },

  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = GlobalConfig.icons.git.added },
        change = { text = GlobalConfig.icons.git.modified },
        delete = { text = GlobalConfig.icons.git.removed },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns

        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = buffer, desc = desc })
        end

        map('n', ']h', gs.next_hunk, 'Next hunk')
        map('n', '[h', gs.prev_hunk, 'Prev hunk')

        map({ 'n', 'v' }, '<leader>ghs', ':Gitsigns stage_hunk<CR>', 'Stage hunk')
        map({ 'n', 'v' }, '<leader>ghr', ':Gitsigns reset_hunk<CR>', 'Reset hunk')
        map('n', '<leader>ghS', gs.undo_stage_hunk, 'Undo stage hunk')

        map('n', '<leader>ghf', gs.stage_buffer, 'Stage file')
        map('n', '<leader>ghR', gs.reset_buffer, 'Reset file')

        map('n', '<leader>ghp', gs.preview_hunk_inline, 'Preview hunk inline')

        map('n', '<leader>ghb', function()
          gs.blame_line { full = true }
        end, 'Blame line')
        map('n', '<leader>ghL', '<cmd>Gitsigns toggle_current_line_blame<CR>', 'Toggle line blame')

        map('n', '<leader>ghd', gs.diffthis, 'Diff this')
        map('n', '<leader>ghD', function()
          gs.diffthis '~'
        end, 'Diff this ~')

        map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', 'Hunk')
        map({ 'o', 'x' }, 'ah', ':<C-U>Gitsigns select_hunk<CR>', 'Hunk')
      end,
    },
  },

  { -- Easily navigate between working files
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    event = 'VeryLazy',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local harpoon = require 'harpoon'
      harpoon.setup {}

      vim.keymap.set('n', '<leader>ma', function()
        harpoon:list():append()
      end, { desc = 'Add current file to harpoon' })

      vim.keymap.set('n', '<leader>mo', function()
        harpoon.ui:toggle_quick_menu(harpoon:list())
      end, { desc = 'Open harpoon menu' })

      vim.keymap.set('n', '<M-q>', function()
        harpoon:list():select(1)
      end)

      vim.keymap.set('n', '<M-w>', function()
        harpoon:list():select(2)
      end)

      vim.keymap.set('n', '<M-e>', function()
        harpoon:list():select(3)
      end)

      vim.keymap.set('n', '<M-d>', function()
        harpoon:list():select(4)
      end)
    end,
  },

  {
    'ggandor/leap.nvim',
    config = function()
      local leap = require 'leap'

      leap.opts.special_keys.prev_target = '<backspace>'
      leap.opts.special_keys.prev_group = '<backspace>'
      leap.opts.safe_labels = {}

      vim.keymap.set({ 'n', 'x', 'o' }, 'm', '<Plug>(leap-forward)')
      vim.keymap.set({ 'n', 'x', 'o' }, 'M', '<Plug>(leap-backward)')
      vim.keymap.set({ 'n', 'x', 'o' }, 'gm', '<Plug>(leap-from-window)')
    end,
  },

  {
    'echasnovski/mini.bufremove',
    keys = {
      {
        '<leader>bd',
        function()
          local bd = require('mini.bufremove').delete

          if vim.bo.modified then
            local choice = vim.fn.confirm(('Save changes to %q?'):format(vim.fn.bufname()), '&Yes\n&No\n&Cancel')

            if choice == 1 then -- yes
              vim.cmd.write()
              bd(0)
            elseif choice == 2 then -- no
              bd(0, true)
            end
          else
            bd(0)
          end
        end,
        desc = 'Close buffer',
      },
      {
        '<leader>bD',
        function()
          require('mini.bufremove').delete(0, true)
        end,
        desc = 'Close! buffer',
      },
    },
  },

  {
    'echasnovski/mini.pairs',
    event = 'VeryLazy',
    opts = {},
    keys = {
      {
        '<leader>up',
        function()
          vim.g.minipairs_disable = not vim.g.minipairs_disable
          if vim.g.minipairs_disable then
            vim.notify('Disabled auto pairs', vim.log.levels.INFO)
          else
            vim.notify('Enabled auto pairs', vim.log.levels.INFO)
          end
        end,
        desc = 'Toggle auto pairs',
      },
    },
  },

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
      window = {
        position = 'float',
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
    },
  },

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        defaults = {
          initial_mode = 'normal',
          mappings = {
            n = {
              ['q'] = require('telescope.actions').close,
              ['P'] = require('telescope.actions.layout').toggle_preview,
            },
          },
        },
        -- pickers = {}
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = 'Help' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = 'Keymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = 'Files' })
      vim.keymap.set('n', '<leader>sb', builtin.buffers, { desc = 'Buffers' })
      vim.keymap.set('n', '<leader>st', builtin.builtin, { desc = 'Telescope builtins' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = 'Current word' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = 'By grep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = 'Diagnostics' })
      vim.keymap.set('n', '<leader>sR', builtin.resume, { desc = 'Resume' })
      vim.keymap.set('n', '<leader>sr', builtin.oldfiles, { desc = 'Recent Files' })
      vim.keymap.set('n', '<leader>:', '<cmd>Telescope command_history<cr>', { desc = 'Command History' })

      vim.keymap.set('n', '<leader>.', builtin.find_files, { desc = 'Search Files' })

      vim.keymap.set('n', '<leader>gC', builtin.git_commits, { desc = 'Project commits' })
      vim.keymap.set('n', '<leader>gc', builtin.git_bcommits, { desc = 'Buffer commits' })
      vim.keymap.set('n', '<leader>gb', builtin.git_branches, { desc = 'Branches' })
      vim.keymap.set('n', '<leader>gs', builtin.git_status, { desc = 'Status' })

      -- Slightly advanced example of overriding default behavior and theme
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          layout_config = {
            width = 0.60,
          },
          winblend = 10,
          previewer = false,
        })
      end, { desc = 'Grep in buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = 'Grep in Open Buffers' })
    end,
  },

  { -- see :Telescope colorscheme
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    init = function()
      -- Options: 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme 'tokyonight-moon'

      -- You can configure highlights by doing something like:
      vim.cmd.hi 'Comment gui=none'
    end,
  },

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VeryLazy',
    config = function()
      require('which-key').setup()

      -- TODO: Add mini-surround

      -- Document existing key chains
      require('which-key').register {
        ['g'] = { name = '+goto' },
        ['s'] = { name = '+surround' },
        ['z'] = { name = '+fold' },
        [']'] = { name = '+next' },
        ['['] = { name = '+prev' },
        ['<leader>b'] = { name = 'Buffer', _ = 'which_key_ignore' },
        ['<leader>c'] = { name = 'Code', _ = 'which_key_ignore' },
        ['<leader>f'] = { name = 'File', _ = 'which_key_ignore' },
        ['<leader>g'] = { name = 'Git', _ = 'which_key_ignore' },
        ['<leader>gh'] = { name = 'Hunk', _ = 'which_key_ignore' },
        ['<leader>s'] = { name = 'Search', _ = 'which_key_ignore' },
        ['<leader>u'] = { name = 'UI', _ = 'which_key_ignore' },
        ['<leader>x'] = { name = 'X Ray', _ = 'which_key_ignore' },
      }
    end,
  },

  { -- Highlight other instances of the word under your cursor.
    'RRethy/vim-illuminate',
    event = 'VimEnter',
    opts = {
      delay = 200,
      large_file_cutoff = 2000,
      large_file_overrides = {
        providers = { 'lsp' },
      },
    },
    config = function(_, opts)
      require('illuminate').configure(opts)

      local function map(key, dir, buffer)
        vim.keymap.set('n', key, function()
          require('illuminate')['goto_' .. dir .. '_reference'](false)
        end, { desc = dir:sub(1, 1):upper() .. dir:sub(2) .. ' Reference', buffer = buffer })
      end

      map(']]', 'next')
      map('[[', 'prev')

      -- also set it after loading ftplugins, since a lot overwrite [[ and ]]
      vim.api.nvim_create_autocmd('FileType', {
        callback = function()
          local buffer = vim.api.nvim_get_current_buf()
          map(']]', 'next', buffer)
          map('[[', 'prev', buffer)
        end,
      })
    end,
    keys = {
      { ']]', desc = 'Next Reference' },
      { '[[', desc = 'Prev Reference' },
    },
  },

  'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically

  { -- Seamlessly navigate between Tmux and Nvim panes
    'christoomey/vim-tmux-navigator',
    cmd = {
      'TmuxNavigateLeft',
      'TmuxNavigateDown',
      'TmuxNavigateUp',
      'TmuxNavigateRight',
      'TmuxNavigatePrevious',
    },
    keys = {
      { '<c-h>', '<cmd><C-U>TmuxNavigateLeft<cr>' },
      { '<c-j>', '<cmd><C-U>TmuxNavigateDown<cr>' },
      { '<c-k>', '<cmd><C-U>TmuxNavigateUp<cr>' },
      { '<c-l>', '<cmd><C-U>TmuxNavigateRight<cr>' },
      { '<c-\\>', '<cmd><C-U>TmuxNavigatePrevious<cr>' },
    },
  },
}
