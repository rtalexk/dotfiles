-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Disable Virtual Text (inline error/warning reporting)
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
  virtual_text = false,
})
