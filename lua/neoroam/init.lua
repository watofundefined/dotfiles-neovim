-- neoroam: org-roam-style backlinks for Markdown notes. See docs/adr/0001-roam-style-backlinks.md
local M = {}

function M.setup(opts)
  require("neoroam.config").setup(opts)
  local cmd = vim.api.nvim_create_user_command
  cmd("NeoroamBacklinks", function() require("neoroam.panel").toggle() end, { desc = "Toggle backlinks panel" })
  cmd("NeoroamFollow", function() require("neoroam.notes").follow() end, { desc = "Follow id link under cursor" })
  cmd("NeoroamInsert", function() require("neoroam.picker").insert() end, { desc = "Insert link to a note" })
  cmd("NeoroamNew", function() require("neoroam.notes").new() end, { desc = "Create a new note" })
end

return M
