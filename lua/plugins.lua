-- See also:
-- - https://lazy.folke.io/spec/examples
-- - nvim/lua/config/lazy.lua

require("lazy").setup({
  -- Telescope
  {
      'nvim-telescope/telescope.nvim',
      version = '*',
      dependencies = {
          'nvim-lua/plenary.nvim',
          -- optional but recommended
          { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
      }
  },
})
 
