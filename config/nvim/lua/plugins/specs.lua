-- neotest
-- neotest-rspec
return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'olimorris/neotest-rspec',
    },
    opts = {
      adapters = {
        ['neotest-rspec'] = {
          rspec_cmd = function()
            return vim.tbl_flatten {
              'bundle',
              'exec',
              'rspec',
            }
          end,
        },
      },
      status = {
        virtual_test = true,
      },
      output = {
        open_on_run = true,
      },
    },
    config = function(_, opts)
      local neotest_ns = vim.api.nvim_create_namespace 'neotest'
      vim.diagnostic.config({
        virtual_text = {
          format = function(diagnostic)
            -- Replace newline, tab and ANSI colors chars with space for more compact diagnostics
            local message = diagnostic.message:gsub('\n', ' '):gsub('\t', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('\27%[%d+%a', '')
            return message
          end,
        },
      }, neotest_ns)

      if opts.adapters then
        local adapters = {}
        for name, config in pairs(opts.adapters or {}) do
          if type(name) == 'number' then
            if type(config) == 'string' then
              config = require(config)
            end
            adapters[#adapters + 1] = config
          elseif config ~= false then
            local adapter = require(name)
            if type(config) == 'table' and not vim.tbl_isempty(config) then
              local meta = getmetatable(adapter)
              if adapter.setup then
                adapter.setup(config)
              elseif meta and meta.__call then
                adapter(config)
              else
                error('Adapter ' .. name .. ' does not support setup')
              end
            end
            adapters[#adapters + 1] = adapter
          end
        end
        opts.adapters = adapters
      end

      require('neotest').setup(opts)
    end,
    keys = {
      {
        '<leader>tf',
        function()
          require('neotest').run.run(vim.fn.expand '%')
        end,
        desc = 'File',
      },
      {
        '<leader>ta',
        function()
          require('neotest').run.run(vim.uv.cwd())
        end,
        desc = 'All',
      },
      {
        '<leader>tl',
        function()
          require('neotest').run.run()
        end,
        desc = 'Line',
      },
      {
        '<leader>tL',
        function()
          require('neotest').run.run_last()
        end,
        desc = 'Last',
      },
      {
        '<leader>tc',
        function()
          require('neotest').output_panel.clear()
        end,
        desc = 'Clear',
      },
      {
        '<leader>ts',
        function()
          require('neotest').summary.toggle()
        end,
        desc = 'Toggle Summary',
      },
      {
        '<leader>to',
        function()
          require('neotest').output.open { enter = true, auto_close = true }
        end,
        desc = 'Show Output',
      },
      {
        '<leader>tp',
        function()
          require('neotest').output_panel.toggle()
        end,
        desc = 'Toggle Panel',
      },
      {
        '<leader>tS',
        function()
          require('neotest').run.stop()
        end,
        desc = 'Stop',
      },
    },
  },
}
