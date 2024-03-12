local Util = require("lazyvim.util")

return {
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      { "<leader>/", false },
      { "<leader><space>", false },
      { "<leader>ff", Util.telescope("files", { cwd = false }), desc = "Find Files (root)" },
      { "<leader>fF", Util.telescope("files"), desc = "Find Files (cwd)" },
      { "<leader>fr", Util.telescope("oldfiles", { cwd = vim.loop.cwd() }), desc = "Recent (root)" },
      { "<leader>fR", "<cmd>Telescope oldfiles<cr>", desc = "Recent (cwd)" },

      { "<leader>`", false }, -- Move to somewhere related to buffers
      { "<leader>-", false }, -- Move to somewhere related to windows
      { "<leader><S-|>", false }, -- Move to somewhere related to windows
      { "<leader>E", false }, -- Move to somewhere related to Neotree
      { "<leader>e", false }, -- Move to somewhere related to Neotree
    },
    opts = function()
      local actions = require("telescope.actions")
      local layout_actions = require("telescope.actions.layout")

      return {
        defaults = {
          initial_mode = "normal",
          preview = {
            hide_on_startup = true,
          },
          mappings = {
            n = {
              ["q"] = actions.close,
              ["p"] = layout_actions.toggle_preview,
            },
          },
        },
      }
    end,
  },
}
