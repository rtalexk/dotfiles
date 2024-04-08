return {
  {
    "rtalexk/telescope-filetypes.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("telescope").load_extension("telescope_filetypes")
      local filetypes = require("telescope_filetypes")
      filetypes.setup()

      vim.keymap.set("n", "<leader>fs", filetypes.show_picker, { desc = "File type/syntax" })
    end,
  },
}
