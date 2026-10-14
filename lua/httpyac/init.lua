-- httpyac: run the HTTP request under the cursor with the httpyac CLI. Requires `npm install -g httpyac`.
local M = {}

function M.setup()
  local group = vim.api.nvim_create_augroup("httpyac", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "http",
    callback = function(a)
      local map = function(lhs, cmd, desc) vim.keymap.set("n", lhs, cmd, { buffer = a.buf, desc = desc }) end
      map("<leader>hr", "<cmd>HttpRun<cr>", "Run HTTP request under cursor")
      map("<leader>he", "<cmd>HttpEnv<cr>", "Choose HTTP environment")
      pcall(vim.treesitter.start, a.buf)
    end,
  })

  vim.api.nvim_create_user_command("HttpRun", function()
    require("httpyac.run").run(0, { line = vim.fn.line(".") })
  end, { desc = "Run HTTP request under cursor" })

  vim.api.nvim_create_user_command("HttpEnv", function()
    local env = require("httpyac.env")
    local root = env.root(vim.api.nvim_buf_get_name(0))
    local names = env.names(root)
    if #names == 0 then return vim.notify("httpyac: no http-client.env.json found", vim.log.levels.WARN) end
    vim.ui.select(names, { prompt = "HTTP environment (current: " .. (env.get(root) or "none") .. ")" }, function(choice)
      if choice then env.set(root, choice) end
    end)
  end, { desc = "Choose HTTP environment" })
end

return M
