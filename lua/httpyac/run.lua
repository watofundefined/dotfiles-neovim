local cli = require("httpyac.cli")
local env = require("httpyac.env")

local M = {}

local seq = 0 -- keeps temp names unique across concurrent runs in this Neovim

local function save_response(r)
  local dir = vim.fn.stdpath("data") .. "/httpyac/responses"
  vim.fn.mkdir(dir, "p")
  local f = io.open(dir .. "/" .. cli.response_filename(r, os.time()), "w")
  if f then
    f:write(r.body)
    f:close()
  end
end

-- target: { line = N } | { all = true }. Runs asynchronously, shows the result in the split.
function M.run(buf, target)
  if vim.fn.executable("httpyac") == 0 then
    return vim.notify("httpyac not found. Install it with: npm install -g httpyac", vim.log.levels.ERROR)
  end
  local file = vim.fs.normalize(vim.api.nvim_buf_get_name(buf))
  local dir = file ~= "" and vim.fs.dirname(file) or vim.fn.getcwd()
  local root = env.root(file ~= "" and file or dir .. "/x")
  local name = env.get(root)

  -- Unsaved edits are sent via a sibling temp file so relative imports still resolve.
  local tmp
  if file == "" or vim.bo[buf].modified then
    seq = seq + 1
    tmp = dir .. "/.httpyac-" .. vim.fn.getpid() .. "-" .. seq .. ".http"
    if not pcall(vim.fn.writefile, vim.api.nvim_buf_get_lines(buf, 0, -1, false), tmp) then
      return vim.notify("httpyac: cannot write temp file in " .. dir, vim.log.levels.ERROR)
    end
    file = tmp
  end

  -- httpyac finds http-client.env.json relative to its cwd, and rejects absolute paths outside it
  -- (symlinks), so run from the env root with a root-relative path.
  local cwd, rel = dir, vim.fs.basename(file)
  if file:sub(1, #root + 1) == root .. "/" then cwd, rel = root, file:sub(#root + 2) end

  vim.notify("httpyac: running…")
  vim.system(cli.build_args(rel, target, name), { text = true, cwd = cwd }, vim.schedule_wrap(function(res)
    if tmp then os.remove(tmp) end
    local r = cli.parse(res.stdout, res.stderr)
    if r.err then return vim.notify("httpyac: " .. r.err, vim.log.levels.ERROR) end
    pcall(save_response, r) -- history is a nicety, never block showing the response
    require("httpyac.view").show(r, { env = name })
  end))
end

return M
