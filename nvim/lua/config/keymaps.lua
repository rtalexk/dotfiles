-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local set = vim.keymap.set

set("n", "<leader>bj", "<cmd>BufferLinePick<cr>", { desc = "Pick buffer to jump", noremap = true })
set("n", "<leader>bx", "<cmd>BufferLinePickClose<cr>", { desc = "Pick buffer to close", remap = true })
set("n", "<leader>ghL", "<cmd>Gitsigns toggle_current_line_blame<cr>", { desc = "Toggle line blame", noremap = true })

-- set({ "n", "v" }, ":q", ":bd", { noremap = true, silent = true })
