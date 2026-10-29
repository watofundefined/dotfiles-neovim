local opt = vim.opt
 
-- UI
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.termguicolors = true
opt.signcolumn = "yes"
 
-- vim.cmd [[colorscheme slate]]
-- Colorscheme is set in plugins.lua (tokyonight.nvim), since plugins load after this file.
-- vim.cmd [[colorscheme unokai]]

-- Distinguish the bracket under the cursor from its matching counterpart.
-- Native matchparen.vim highlights both with the same `MatchParen` group;
-- the cursor's own bracket is visually covered by the terminal cursor block
-- (the `Cursor` highlight), so we can style each independently:
--   * Cursor (bracket under cursor)   -> bright gold accent already used by
--     this theme for Title/MatchParen/Question, so it reads as "primary".
--   * MatchParen (counterpart bracket) -> a muted gray box instead of gold,
--     so it doesn't compete for attention with the cursor position.
--     (light gray box when background=light, e.g. tokyonight-day)
local function tune_paren_colors()
  vim.api.nvim_set_hl(0, "Cursor", { fg = "#262626", bg = "#ffd700" })
  if vim.o.background == "light" then
    vim.api.nvim_set_hl(0, "MatchParen", { fg = "#3760bf", bg = "#c4c8da", bold = true })
  else
    vim.api.nvim_set_hl(0, "MatchParen", { fg = "#cccccc", bg = "#4a4a4a", bold = true })
  end
end
tune_paren_colors()
vim.api.nvim_create_autocmd("ColorScheme", { callback = tune_paren_colors })
 


-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = false
opt.incsearch = true
 
-- Indentation
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.smartindent = true
 
-- Behavior
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.updatetime = 250
opt.timeoutlen = 300
 
-- Splits
opt.splitbelow = true
opt.splitright = true
