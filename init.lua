require("config.lazy")
require("options")
require("autocmds")
require("plugins")
require("lsp")
-- load plugins before keymaps
require("keymaps")

require("neoroam").setup({ notes_root = "Roam" })
