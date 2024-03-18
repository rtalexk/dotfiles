return {
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local harpoon = require("harpoon")
      harpoon.setup({})

      vim.keymap.set("n", "<leader>ma", function()
        harpoon:list():append()
      end, { desc = "Add current file to harpoon" })

      vim.keymap.set("n", "<leader>mo", function()
        harpoon.ui:toggle_quick_menu(harpoon:list())
      end, { desc = "Open harpoon menu" })

      vim.keymap.set("n", "<M-q>", function()
        harpoon:list():select(1)
      end)

      vim.keymap.set("n", "<M-w>", function()
        harpoon:list():select(2)
      end)

      vim.keymap.set("n", "<M-e>", function()
        harpoon:list():select(3)
      end)

      vim.keymap.set("n", "<M-d>", function()
        harpoon:list():select(4)
      end)
    end,
  },
}
