return {
	{
		"nvim-treesitter/nvim-treesitter",
		optional = true,
		opts = function()
			require("textobjects").setup()
		end,
	},
}
