return {
  'file-utils',
  name = 'file-utils',
  dir = vim.fn.stdpath 'config',
  config = function()
    local function copy_with_line_info(path, label, opts)
      local result = path
      if opts.args == 'line' then
        if opts.range == 2 then
          result = result .. ':' .. opts.line1 .. '-' .. opts.line2
        else
          local line = vim.fn.line '.'
          result = result .. ':' .. line
        end
      end
      vim.fn.setreg('+', result)
      print('Copied ' .. label .. ': ' .. result)
    end

    vim.api.nvim_create_user_command('FUCopyAbsoluteDir', function()
      local filedir = vim.fn.expand '%:p:h'
      vim.fn.setreg('+', filedir)
      print('Copied absolute directory: ' .. filedir)
    end, { desc = 'Copy absolute filepath (without name)' })

    vim.api.nvim_create_user_command('FUCopyAbsolutePath', function(opts)
      local filepath = vim.fn.expand '%:p'
      copy_with_line_info(filepath, 'absolute filepath', opts)
    end, { nargs = '?', range = true, desc = 'Copy absolute filepath (with name)' })

    vim.api.nvim_create_user_command('FUCopyDir', function()
      local relative_path = vim.fn.expand '%:.'
      local relative_dir = vim.fn.fnamemodify(relative_path, ':h')
      vim.fn.setreg('+', relative_dir)
      print('Copied relative directory: ' .. relative_dir)
    end, { desc = 'Copy relative filepath (without name)' })

    vim.api.nvim_create_user_command('FUCopyName', function(opts)
      local filename = vim.fn.expand '%:t'
      copy_with_line_info(filename, 'filename', opts)
    end, { nargs = '?', range = true, desc = 'Copy file name (without path)' })

    vim.api.nvim_create_user_command('FUCopyPath', function(opts)
      local relative_path = vim.fn.expand '%:.'
      copy_with_line_info(relative_path, 'relative filepath', opts)
    end, { nargs = '?', range = true, desc = 'Copy relative filepath (with name)' })
  end,
}
