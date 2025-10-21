-- Mason
-- Mason LspConfig
-- Mason Tool Installer
-- Fidget
-- Neodev

return {
  { -- LSP Configuration & Plugins
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },

      -- `neodev` configures Lua LSP for your Neovim config, runtime and plugins
      -- used for completion, annotations and signatures of Neovim apis
      { 'folke/neodev.nvim', opts = {} },
    },
    opts = {
      diagnostics = {
        virtual_text = {
          spacing = 4,
          source = 'if_many',
          prefix = 'icons',
        },
        severity_sort = true,
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = ' ',
            [vim.diagnostic.severity.WARN] = ' ',
            [vim.diagnostic.severity.HINT] = ' ',
            [vim.diagnostic.severity.INFO] = ' ',
          },
          linehl = {
            [vim.diagnostic.severity.ERROR] = 'ErrorMsg',
          },
          numhl = {
            [vim.diagnostic.severity.WARN] = 'WarningMsg',
          },
        },
        float = {
          source = 'always',
          header = '',
          prefix = '',
        },
      },
    },
    config = function(_, opts)
      -- Track the current LSP hover window
      local hover_win_id = nil

      -- Configure diagnostic floating windows
      opts.diagnostics.float = opts.diagnostics.float or {}
      opts.diagnostics.float.border = GlobalConfig.border

      -- Function to set floating window highlights with Catppuccin colors
      local function set_float_highlights()
        vim.api.nvim_set_hl(0, 'FloatBorder', {
          bg = 'NONE',
          fg = '#89b4fa', -- Catppuccin blue
          bold = true,
        })
        vim.api.nvim_set_hl(0, 'NormalFloat', {
          bg = '#1e1e2e', -- Catppuccin base
          fg = '#cdd6f4', -- Catppuccin text
        })
        vim.api.nvim_set_hl(0, 'Pmenu', { bg = '#1e1e2e', fg = '#cdd6f4' })
        vim.api.nvim_set_hl(0, 'PmenuSel', { bg = '#45475a', fg = '#cdd6f4' })
      end

      -- Set highlights immediately and after colorscheme changes
      set_float_highlights()

      -- Also set highlights after a delay to ensure they override theme settings
      vim.defer_fn(set_float_highlights, 100)

      vim.api.nvim_create_autocmd('ColorScheme', {
        callback = function()
          vim.defer_fn(set_float_highlights, 50)
        end,
        desc = 'Set floating window highlights after colorscheme change',
      })

      -- Override the core LSP floating preview function to add borders and track hover windows
      local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
      function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
        opts = opts or {}
        opts.border = opts.border or GlobalConfig.border
        opts.max_width = opts.max_width or 80
        opts.max_height = opts.max_height or 20
        local bufnr, win_id = orig_util_open_floating_preview(contents, syntax, opts, ...)

        -- Track this window if it's a hover window (check if called from hover)
        local info = debug.getinfo(3, 'n')
        if info and info.name == 'hover' then
          hover_win_id = win_id

          -- Set up autocmd to clean up hover_win_id when window is closed
          vim.api.nvim_create_autocmd('WinClosed', {
            pattern = tostring(win_id),
            callback = function()
              if hover_win_id == win_id then
                hover_win_id = nil
              end
            end,
            once = true,
          })
        end

        return bufnr, win_id
      end

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('<leader>cr', vim.lsp.buf.rename, 'Code Rename')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('<leader>ca', vim.lsp.buf.code_action, 'Code Action')

          -- Opens a popup that displays documentation about the word under your cursor
          --  See `:help K` for why this keymap.
          local function toggle_hover()
            -- State 1: No hover window exists -> Open hover
            if not hover_win_id or not vim.api.nvim_win_is_valid(hover_win_id) then
              hover_win_id = nil
              vim.lsp.buf.hover()
              return
            end

            -- State 2: Hover window exists but cursor not in it -> Focus hover window
            local current_win = vim.api.nvim_get_current_win()
            if current_win ~= hover_win_id then
              vim.api.nvim_set_current_win(hover_win_id)
              return
            end

            -- State 3: Cursor is in hover window -> Close hover window
            vim.api.nvim_win_close(hover_win_id, false)
            hover_win_id = nil
          end
          map('K', toggle_hover, 'Toggle Hover Documentation')

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('gD', vim.lsp.buf.declaration, 'Goto Declaration')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.server_capabilities.documentHighlightProvider then
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              callback = vim.lsp.buf.clear_references,
            })
          end
        end,
      })

      -- Global K keymap to handle hover windows from any buffer
      vim.keymap.set('n', 'K', function()
        local current_win = vim.api.nvim_get_current_win()

        -- If we're in a tracked hover window, close it
        if hover_win_id and vim.api.nvim_win_is_valid(hover_win_id) and current_win == hover_win_id then
          vim.api.nvim_win_close(hover_win_id, false)
          hover_win_id = nil
          return
        end

        -- Otherwise, check if there's a buffer-local K mapping and use it
        local buf_keymaps = vim.api.nvim_buf_get_keymap(0, 'n')
        for _, map in ipairs(buf_keymaps) do
          if map.lhs == 'K' and map.buffer == 1 then
            -- Execute the buffer-local K mapping function
            if map.callback then
              map.callback()
            else
              vim.cmd(map.rhs or 'normal! K')
            end
            return
          end
        end

        -- Check if we're in a floating window (likely a popup we don't control)
        local win_config = vim.api.nvim_win_get_config(current_win)
        if win_config.relative ~= '' then
          -- We're in a floating window, try to close it or do nothing
          if vim.bo.buftype == 'nofile' then
            -- This is likely a popup, try closing with q first
            local ok = pcall(vim.cmd, 'close')
            if not ok then
              -- If close doesn't work, do nothing rather than trigger man page
              return
            end
          end
        else
          -- We're in a normal window, safe to use default K behavior
          vim.cmd 'normal! K'
        end
      end, { desc = 'Smart hover toggle' })

      -- diagnostics signs
      if vim.fn.has 'nvim-0.10.0' == 0 then
        for severity, icon in pairs(opts.diagnostics.signs.text) do
          local name = vim.diagnostic.severity[severity]:lower():gsub('^%l', string.upper)
          name = 'DiagnosticSign' .. name
          vim.fn.sign_define(name, { text = icon, texthl = name, numhl = '' })
        end
      end

      -- Virtual Text
      if type(opts.diagnostics.virtual_text) == 'table' and opts.diagnostics.virtual_text.prefix == 'icons' then
        opts.diagnostics.virtual_text.prefix = vim.fn.has 'nvim-0.10.0' == 0 and '●'
          or function(diagnostic)
            local icons = GlobalConfig.icons
            for d, icon in pairs(icons) do
              if diagnostic.severity == vim.diagnostic.severity[d:upper()] then
                return icon
              end
            end
          end
      end

      vim.keymap.set('n', '<leader>uv', function()
        if vim.diagnostic.config().virtual_text then
          vim.diagnostic.config { virtual_text = false }
        else
          vim.diagnostic.config { virtual_text = opts.diagnostics.virtual_text }
        end
      end, { desc = 'Toggle diagnostic Virtual Text' })

      vim.diagnostic.config(vim.deepcopy(opts.diagnostics))

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

      -- Enable the following language servers
      --
      --  Add any additional override configuration in the following tables. Available keys are:
      --  - cmd (table): Override the default command used to start the server
      --  - filetypes (table): Override the default list of associated filetypes for the server
      --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
      --  - settings (table): Override the default settings passed when initializing the server.
      --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
      local servers = {
        -- clangd = {},
        -- gopls = {},
        -- pyright = {},
        -- rust_analyzer = {},
        -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
        --
        -- Some languages (like typescript) have entire language plugins that can be useful:
        --    https://github.com/pmizio/typescript-tools.nvim
        --
        -- But for many setups, the LSP (`tsserver`) will work just fine
        -- tsserver = {},
        --
        -- Ruby LSP
        -- solargraph = {},
        -- standardrb = {},

        -- Markdown LSP
        marksman = {},

        -- ESLint LSP
        eslint = {},

        lua_ls = {
          -- cmd = {...},
          -- filetypes = { ...},
          -- capabilities = {},
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
              -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
              diagnostics = { disable = { 'missing-fields' } },
            },
          },
        },
      }

      -- Ensure the servers and tools above are installed
      --  To check the current status of installed tools and/or manually install
      --  other tools, you can run
      --    :Mason
      --
      --  You can press `g?` for help in this menu.
      local package_icons = GlobalConfig.icons.packages
      require('mason').setup {
        ui = {
          icons = {
            package_installed = package_icons.installed,
            package_pending = package_icons.pending,
            package_uninstalled = package_icons.uninstalled,
          },
        },
      }

      -- You can add other tools here that you want Mason to install
      -- for you, so that they are available from within Neovim.
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'stylua', -- Used to format Lua code
        'shfmt', -- Used to format Bash code
        'prettier', -- To format a lot of langs in the JS ecosystem
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      require('mason-lspconfig').setup {
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            -- This handles overriding only values explicitly passed
            -- by the server configuration above. Useful when disabling
            -- certain features of an LSP (for example, turning off formatting for tsserver)
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }
    end,
  },
}
