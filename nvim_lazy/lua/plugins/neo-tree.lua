local Util = require("lazyvim.util")

return {
  "nvim-neo-tree/neo-tree.nvim",
  keys = {
    -- Invert fe & fE. I prefer opening the File Explorer in the cwd of Nvim (which I change using my CLI)
    {
      "<leader>fe",
      function()
        require("neo-tree.command").execute({ toggle = true, dir = vim.loop.cwd() })
      end,
      desc = "File Explorer (root)",
    },
    {
      "<leader>fE",
      function()
        require("neo-tree.command").execute({ toggle = true, dir = Util.root() })
      end,
      desc = "File Explorer (cwd)",
    },
    { "<leader>e", "<leader>fe", desc = "File Explorer (root)", remap = true },
    { "<leader>E", "<leader>fE", desc = "File Explorer  (cwd)", remap = true },
  },
  opts = {
    window = {
      position = "right",
    },
    filesystem = {
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },
  },
}
