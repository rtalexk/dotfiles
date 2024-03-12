-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local set = vim.keymap.set

-- Buffers
set("n", "<leader>bj", "<cmd>BufferLinePick<cr>", { desc = "Pick buffer to jump", noremap = true })
set("n", "<leader>bx", "<cmd>BufferLinePickClose<cr>", { desc = "Pick buffer to close", noremap = true })

-- Git
set("n", "<leader>ghL", "<cmd>Gitsigns toggle_current_line_blame<cr>", { desc = "Toggle line blame", noremap = true })

-- NoNeckPain
set("n", "<leader>uN", "<cmd>NoNeckPain<cr>", { desc = "Toggle NoNeckPain", noremap = true })

-- Noice
set("n", "<leader>snf", "<cmd>Telescope noice<cr>", { desc = "Fuzzy search", noremap = true })

-- Quit buffer instead of Window
-- set({ "n", "v" }, ":q", ":bd", { noremap = true, silent = true })

--
vim.api.nvim_del_keymap("n", "<leader>-") -- Split horizontal
vim.api.nvim_del_keymap("n", "<leader>|") -- Split vertical
vim.api.nvim_del_keymap("n", "<leader>`") -- Switch to last buffer

-- lazy
-- vim.keymap.set("n", "<leader>l", "<cmd>Lazy<cr>", { desc = "Lazy" }) TODO: Create a Menu for Lazy

-- Terminal
vim.api.nvim_del_keymap("n", "<c-/>") -- TODO: Remove from WhichKey
vim.api.nvim_del_keymap("n", "<C-Bslash>") -- TODO: Remove from WhichKey
