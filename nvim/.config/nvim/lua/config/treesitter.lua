local M = {}

M.ensure_installed = {
  'bash',
  'c',
  'css',
  'dockerfile',
  'gitignore',
  'html',
  'javascript',
  'json',
  'lua',
  'luadoc',
  'markdown',
  'markdown_inline',
  'ruby',
  'tsx',
  'typescript',
  'vim',
  'vimdoc',
}

-- Ruby depends on vim's regex highlighting for its indent rules
local vim_regex_highlight = { ruby = true }
local disable_indent = { ruby = true }

local installed = {}
local available = nil

local function refresh_installed()
  installed = {}
  for _, lang in ipairs(require('nvim-treesitter').get_installed 'parsers') do
    installed[lang] = true
  end
end

local function is_available(lang)
  if not available then
    available = {}
    for _, l in ipairs(require('nvim-treesitter').get_available()) do
      available[l] = true
    end
  end
  return available[lang] == true
end

local function attach(buf, lang)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local ok = pcall(vim.treesitter.start, buf, lang)
  if not ok then
    return
  end

  if vim_regex_highlight[lang] then
    vim.bo[buf].syntax = 'ON'
  end

  if not disable_indent[lang] then
    vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end

  require('config.ts_selection').attach(buf)
end

local function on_filetype(ev)
  local ft = ev.match
  local lang = vim.treesitter.language.get_lang(ft)
  if not lang then
    return
  end

  if installed[lang] then
    attach(ev.buf, lang)
    return
  end

  if not is_available(lang) then
    return
  end

  require('nvim-treesitter').install({ lang }):await(function(err)
    if err then
      return
    end
    vim.schedule(function()
      refresh_installed()
      if vim.api.nvim_buf_is_valid(ev.buf) and vim.bo[ev.buf].filetype == ft then
        attach(ev.buf, lang)
      end
    end)
  end)
end

function M.setup()
  require('nvim-treesitter').setup {}
  refresh_installed()

  require('nvim-treesitter').install(M.ensure_installed):await(function()
    vim.schedule(refresh_installed)
  end)

  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('rtk_treesitter', { clear = true }),
    callback = on_filetype,
  })
end

return M
