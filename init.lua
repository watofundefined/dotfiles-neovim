require("config.lazy")
require("options")
require("autocmds")
require("plugins")
-- load plugins before keymaps
require("keymaps")

require("neoroam").setup()
