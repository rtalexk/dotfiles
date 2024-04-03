local Util = require("lazyvim.util")

return {
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      { "<leader>/", false }, -- Live Grep
      { "<leader>,", false }, -- Switch buffer
      { "<leader><space>", false }, -- Find Files

      -- Invert root vs cwd
      { "<leader>ff", Util.telescope("files", { cwd = false }), desc = "Find Files (root)" },
      { "<leader>fF", Util.telescope("files"), desc = "Find Files (cwd)" },
      { "<leader>fr", Util.telescope("oldfiles", { cwd = vim.loop.cwd() }), desc = "Recent (root)" },
      { "<leader>fR", "<cmd>Telescope oldfiles<cr>", desc = "Recent (cwd)" },
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
              ["P"] = layout_actions.toggle_preview,
            },
          },
        },
      }
    end,
  },
}
