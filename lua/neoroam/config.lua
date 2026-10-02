local M = {}

local defaults = {
  notes_root = nil, -- relative to the git root; falls back to vim.g.neoroam_notes_root
  preview_lines = 3,
  panel_width = 45,
  debounce_ms = 150,
}

local opts = {}

function M.setup(user)
  opts = vim.tbl_extend("force", opts, user or {})
end

function M.get()
  local c = vim.tbl_extend("force", defaults, opts)
  if c.notes_root == nil or c.notes_root == "" then
    c.notes_root = vim.g.neoroam_notes_root
  end
  if c.notes_root == "" then
    c.notes_root = nil
  end
  return c
end

return M
