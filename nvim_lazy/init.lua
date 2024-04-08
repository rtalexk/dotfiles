-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

P = function(v)
  print(vim.inspect(v))
  return v
end

-- Disable Virtual Text (inline error/warning reporting)
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
  virtual_text = false,
})

vim.env.WITHIN_EDITOR = "1"

-----------------------------------
-- Toggle Markdown item
-----------------------------------
local function isMdItemChecked()
  local line = vim.fn.getline(".")
  return string.match(line, "^%s*%-%s%[%s*[xX]%s*%]")
end

local function isMdItemUnchecked()
  local line = vim.fn.getline(".")
  return string.match(line, "^%s*%-%s%[%s%]")
end

local function isMdItem()
  return isMdItemUnchecked() or isMdItemChecked()
end

local function mdCompleteItem()
  -- Execute the series of keys: 02f\srx
  vim.api.nvim_feedkeys("0f[lrx2wv", "n", true)
  vim.api.nvim_feedkeys("$gsa~", "v", true)
  vim.api.nvim_feedkeys("v", "n", true)
  vim.api.nvim_feedkeys("i~gsa~", "v", true)
end

local function mdUncompleteItem()
  local line = vim.fn.getline(".")

  local modified_line = string.gsub(line, "~~", "")
  modified_line = string.gsub(modified_line, "%-%s*%[%s*[xX]%s*%]", "- [ ]")

  -- Update the current line with the modified one
  vim.fn.setline(".", modified_line)
end

function MdToggleItem()
  if not isMdItem() then
    -- Send an info message to the user
    vim.api.nvim_out_write("Not a markdown list item\n")
    return
  end

  if isMdItemChecked() then
    mdUncompleteItem()
  else
    mdCompleteItem()
  end
end

vim.cmd("command! -nargs=0 MdToggleItem lua MdToggleItem()")
-----------------------------------
