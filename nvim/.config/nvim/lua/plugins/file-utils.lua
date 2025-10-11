return {
  'file-utils',
  name = 'file-utils',
  dir = vim.fn.stdpath 'config',
  config = function()
    -- File utility commands for copying various file path components

    vim.api.nvim_create_user_command('FUCopyAbsoluteDir', function()
      local filedir = vim.fn.expand '%:p:h'
      vim.fn.setreg('+', filedir)
      print('Copied absolute directory: ' .. filedir)
    end, { desc = 'Copy absolute filepath (without name)' })

    vim.api.nvim_create_user_command('FUCopyAbsolutePath', function()
      local filepath = vim.fn.expand '%:p'
      vim.fn.setreg('+', filepath)
      print('Copied absolute filepath: ' .. filepath)
    end, { desc = 'Copy absolute filepath (with name)' })

    vim.api.nvim_create_user_command('FUCopyDir', function()
      local relative_path = vim.fn.expand '%:.'
      local relative_dir = vim.fn.fnamemodify(relative_path, ':h')
      vim.fn.setreg('+', relative_dir)
      print('Copied relative directory: ' .. relative_dir)
    end, { desc = 'Copy relative filepath (without name)' })

    vim.api.nvim_create_user_command('FUCopyName', function()
      local filename = vim.fn.expand '%:t'
      vim.fn.setreg('+', filename)
      print('Copied filename: ' .. filename)
    end, { desc = 'Copy file name (without path)' })

    vim.api.nvim_create_user_command('FUCopyPath', function()
      local relative_path = vim.fn.expand '%:.'
      vim.fn.setreg('+', relative_path)
      print('Copied relative filepath: ' .. relative_path)
    end, { desc = 'Copy relative filepath (with name)' })
  end,
}
