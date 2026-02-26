-- Env vars used by my CLI
vim.env.WITHIN_EDITOR = '1'
vim.env.NVIM_SERVER = vim.v.servername

P = function(v)
  print(vim.inspect(v))
  return v
end

PP = function(v)
  local lines = vim.split(vim.inspect(v), '\n')
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'lua')
  vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = math.min(120, vim.o.columns - 4),
    height = math.min(#lines, vim.o.lines - 4),
    row = 2,
    col = 2,
    style = 'minimal',
    border = 'rounded',
  })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })
  return v
end

require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
require 'config.globals'

local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=stable',
    'https://github.com/folke/lazy.nvim.git',
    lazypath,
  }
end

---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

require('lazy').setup('plugins', {
  change_detection = {
    notify = false,
  },
})

-- See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
