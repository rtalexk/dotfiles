return {

  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'

      -- Custom ESLint linter that uses project-local eslint
      lint.linters.eslint_project = {
        name = 'eslint',
        cmd = function()
          local root_dir = vim.fn.fnamemodify(vim.fn.expand '%:p', ':h')
          local eslint_paths = {
            root_dir .. '/node_modules/.bin/eslint',
            vim.fn.getcwd() .. '/node_modules/.bin/eslint',
          }

          for _, path in ipairs(eslint_paths) do
            if vim.fn.executable(path) == 1 then
              return path
            end
          end

          -- Fall back to global eslint if available
          if vim.fn.executable 'eslint' == 1 then
            return 'eslint'
          end

          -- Return nil to disable linting if no eslint found
          return nil
        end,
        stdin = true,
        args = {
          '--format',
          'json',
          '--stdin',
          '--stdin-filename',
          function()
            return vim.api.nvim_buf_get_name(0)
          end,
        },
        stream = 'stdout',
        ignore_exitcode = true,
        parser = require('lint.linters.eslint').parser,
      }

      lint.linters_by_ft = {
        markdown = { 'markdownlint' },
        javascript = { 'eslint_project' },
        typescript = { 'eslint_project' },
        javascriptreact = { 'eslint_project' },
        typescriptreact = { 'eslint_project' },
      }

      -- To allow other plugins to add linters to require('lint').linters_by_ft,
      -- instead set linters_by_ft like this:
      -- lint.linters_by_ft = lint.linters_by_ft or {}
      -- lint.linters_by_ft['markdown'] = { 'markdownlint' }
      --
      -- However, note that this will enable a set of default linters,
      -- which will cause errors unless these tools are available:
      -- {
      --   clojure = { "clj-kondo" },
      --   dockerfile = { "hadolint" },
      --   inko = { "inko" },
      --   janet = { "janet" },
      --   json = { "jsonlint" },
      --   markdown = { "vale" },
      --   rst = { "vale" },
      --   ruby = { "ruby" },
      --   terraform = { "tflint" },
      --   text = { "vale" }
      -- }
      --
      -- You can disable the default linters by setting their filetypes to nil:
      -- lint.linters_by_ft['clojure'] = nil
      -- lint.linters_by_ft['dockerfile'] = nil
      -- lint.linters_by_ft['inko'] = nil
      -- lint.linters_by_ft['janet'] = nil
      -- lint.linters_by_ft['json'] = nil
      -- lint.linters_by_ft['markdown'] = nil
      -- lint.linters_by_ft['rst'] = nil
      -- lint.linters_by_ft['ruby'] = nil
      -- lint.linters_by_ft['terraform'] = nil
      -- lint.linters_by_ft['text'] = nil

      -- Create autocommand which carries out the actual linting
      -- on the specified events.
      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          local lint_instance = require 'lint'
          local ft = vim.bo.filetype
          local linters = lint_instance.linters_by_ft[ft]

          if linters then
            for _, linter_name in ipairs(linters) do
              local linter = lint_instance.linters[linter_name]
              if linter and type(linter.cmd) == 'function' then
                local cmd = linter.cmd()
                if not cmd then
                  -- Skip linting if no command available
                  return
                end
              end
            end
          end

          lint_instance.try_lint()
        end,
      })
    end,
  },
}
