return {
  {
    "nvim-telescope/telescope.nvim",
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
