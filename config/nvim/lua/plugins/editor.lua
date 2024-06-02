-- Comment
-- Todo Comments
-- GitSigns
-- Harpoon2
-- Leap
-- mini.bufremove
-- mini.pairs
-- Telescope
-- Vim Illuminate
-- Vim Sleuth
-- Vim Tmux Navigator
-- WhichKey

return {
  { -- "gc" to comment visual regions/lines
    'numToStr/Comment.nvim',
    opts = {},
  },

  { -- Highlight todo, notes, etc in comments
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      keywords = {
        TODO = { icon = '', color = 'info' },
      },
      highlight = {
        after = '',
      },
    },
  },

  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '-' },
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
      harpoon.setup {
        settings = {
          save_on_toggle = true,
          save_on_change = true,
        },
      }

      vim.keymap.set('n', '<leader>ma', function()
        harpoon:list():add()
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
    opts = {
      silent = true,
    },
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
      {
        '<leader>bo',
        function()
          local bd = require('mini.bufremove').delete
          local unsaved_changes = function(buf)
            return vim.api.nvim_buf_get_option(buf, 'modified')
          end

          local close_bufs = function(bufs)
            for _, buf in ipairs(bufs) do
              if unsaved_changes(buf) then
                local prompt = ('Save changes to %q?'):format(vim.api.nvim_buf_get_name(buf))
                local choice = vim.fn.confirm(prompt, '&Yes\n&No\n&Cancel')

                if choice == 1 then -- yes
                  vim.api.nvim_buf_call(buf, function()
                    vim.cmd.write()
                  end)
                  bd(buf)
                elseif choice == 2 then -- no
                  bd(buf, true)
                end
              else
                bd(buf)
              end
            end
          end

          local current_buf = vim.fn.bufnr()
          local other_bufs = vim.tbl_filter(function(b)
            return b ~= current_buf
          end, vim.api.nvim_list_bufs())

          close_bufs(other_bufs)
        end,
        desc = 'Close other buffers',
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
      local teleconfig = require('telescope.config').values
      local vimgrep_args = { unpack(teleconfig.vimgrep_arguments) }

      -- I want to search in hidden/dot files.
      table.insert(vimgrep_args, '--hidden')
      -- I don't want to search in the `.git` directory.
      table.insert(vimgrep_args, '--glob')
      table.insert(vimgrep_args, '!**/.git/*')

      require('telescope').setup {
        defaults = {
          vimgrep_arguments = vimgrep_args,
          initial_mode = 'normal',
          preview = {
            hide_on_startup = true,
          },
          layout_strategy = 'vertical',
          layout_config = {
            vertical = {
              width = 0.9,
              preview_height = 0.70,
            },
          },
          path_display = { 'filename_first' },
          mappings = {
            n = {
              ['q'] = require('telescope.actions').close,
              ['<M-p>'] = require('telescope.actions.layout').toggle_preview,
              ['<C-n>'] = require('telescope.actions').move_selection_next,
              ['<C-p>'] = require('telescope.actions').move_selection_previous,
            },
            i = {
              ['<M-p>'] = require('telescope.actions.layout').toggle_preview,
              ['<C-n>'] = require('telescope.actions').move_selection_next,
              ['<C-p>'] = require('telescope.actions').move_selection_previous,
            },
          },
        },
        pickers = {
          find_files = {
            find_command = { 'rg', '--files', '--hidden', '--glob', '!**/.git/*' },
          },
        },
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
        ['<leader>t'] = { name = 'Test', _ = 'which_key_ignore' },
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
