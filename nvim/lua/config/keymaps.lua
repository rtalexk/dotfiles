-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local Util = require("lazyvim.util")
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
vim.api.nvim_del_keymap("n", "<C-b>") -- Scroll backward
vim.api.nvim_del_keymap("n", "<C-f>") -- Scroll forward

-- lazy
-- vim.keymap.set("n", "<leader>l", "<cmd>Lazy<cr>", { desc = "Lazy" }) TODO: Create a Menu for Lazy

-- Terminal
local lazyterm = function()
  Util.terminal(nil, { cwd = Util.root() })
end

-- set("n", "<c-/>", lazyterm, { desc = "which_key_ignore" })
-- vim.api.nvim_del_keymap("n", "<c-/>")

set("n", "<c-_>", lazyterm, { desc = "Floating Terminal" })

-- Save files
set("n", "<leader>fw", "<cmd>w<cr><esc>", { desc = "Save file", noremap = true })
set("n", "<leader>fW", "<cmd>wa<cr><esc>", { desc = "Save all files", noremap = true })

-- Scrolling
set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down" })
set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up" })
