-- Env Var used by my CLI
vim.env.WITHIN_EDITOR = '1'

-- Print/Inspect objects for debugging
P = function(v)
  print(vim.inspect(v))
  return v
end

require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
require 'config.globals'

-- Install Lazy
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

require('lazy').setup 'plugins'

-- See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et