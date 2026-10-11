-- Neovim names a buffer's undofile after its full path, replacing each '/'
-- with '%'. Deeply nested paths produce a name past the filesystem's 255 byte
-- limit for a single component, and writing it fails with E828. Those buffers
-- get a short hashed name instead, read and written by hand.

local hashed_dir = vim.fn.stdpath('state') .. '/undo-hashed'
local max_name_bytes = 255

-- Returns the hashed undofile path for a buffer whose native one is too long,
-- or nil when the native undofile works and should be left alone.
local function hashed_undofile(buf)
  if vim.bo[buf].buftype ~= '' then
    return nil
  end

  local path = vim.api.nvim_buf_get_name(buf)
  if path == '' then
    return nil
  end

  local native = vim.fn.undofile(path):match('[^/]*$')
  if not native or #native <= max_name_bytes then
    return nil
  end

  local label = vim.fn.fnamemodify(path, ':t'):gsub('[^%w%-%._]', '_'):sub(1, 40)
  return hashed_dir .. '/' .. label .. '%' .. vim.fn.sha256(path)
end

local group = vim.api.nvim_create_augroup('hashed-undofile', { clear = true })

vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufNewFile' }, {
  group = group,
  desc = 'Disable the native undofile when its name would be too long',
  callback = function(args)
    if hashed_undofile(args.buf) then
      vim.bo[args.buf].undofile = false
    end
  end,
})

vim.api.nvim_create_autocmd('BufReadPost', {
  group = group,
  desc = 'Load the hashed undofile',
  callback = function(args)
    if args.buf ~= vim.api.nvim_get_current_buf() then
      return
    end
    local file = hashed_undofile(args.buf)
    if file and vim.uv.fs_stat(file) then
      vim.cmd('silent! rundo ' .. vim.fn.fnameescape(file))
    end
  end,
})

vim.api.nvim_create_autocmd('BufWritePost', {
  group = group,
  desc = 'Save the hashed undofile',
  callback = function(args)
    if args.buf ~= vim.api.nvim_get_current_buf() then
      return
    end
    local file = hashed_undofile(args.buf)
    if not file then
      return
    end
    vim.fn.mkdir(hashed_dir, 'p')
    vim.cmd('silent! wundo ' .. vim.fn.fnameescape(file))
  end,
})
