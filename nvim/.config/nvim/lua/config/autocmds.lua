--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_user_command('El', function(opts)
  local arg = opts.args
  local file, line = arg:match('^(.+):(%d+)')

  if file and line then
    vim.cmd('edit ' .. vim.fn.fnameescape(file))
    vim.cmd('normal! ' .. line .. 'G')
  else
    vim.cmd('edit ' .. vim.fn.fnameescape(arg))
  end
end, {
  nargs = 1,
  complete = 'file',
  desc = 'Edit file with optional :line or :line-range syntax'
})
