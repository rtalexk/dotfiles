if true then
  return {}
end

return {
  { -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl', -- See `:help ibl`
    opts = {},
  },
}
