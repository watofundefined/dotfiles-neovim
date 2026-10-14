-- Environments from http-client[.private].env.json and the last chosen one per project.
local M = {}

M.store = vim.fn.stdpath("data") .. "/httpyac/env.json"

-- warn: notify when the file exists but is not valid JSON (otherwise it just looks empty).
local function read_json(path, warn)
  local f = io.open(path)
  if not f then return nil end
  local text = f:read("*a"):gsub("^\239\187\191", "") -- Windows editors add a UTF-8 BOM
  f:close()
  local ok, data = pcall(vim.json.decode, text)
  if not (ok and type(data) == "table") then
    if warn then vim.notify("httpyac: invalid JSON in " .. path .. (ok and "" or ": " .. tostring(data)), vim.log.levels.WARN) end
    return nil
  end
  return data
end

function M.root(file)
  local dir = vim.fs.dirname(file)
  return vim.fs.root(dir, { "http-client.env.json", "http-client.private.env.json" }) or dir
end

function M.names(root)
  local set = {}
  for _, f in ipairs({ "http-client.env.json", "http-client.private.env.json" }) do
    for k in pairs(read_json(root .. "/" .. f, true) or {}) do
      if k ~= "$shared" then set[k] = true end
    end
  end
  local names = vim.tbl_keys(set)
  table.sort(names)
  return names
end

function M.get(root)
  return (read_json(M.store) or {})[root]
end

function M.set(root, name)
  local data = read_json(M.store) or {}
  data[root] = name
  vim.fn.mkdir(vim.fs.dirname(M.store), "p")
  local f = assert(io.open(M.store, "w"))
  f:write(vim.json.encode(data))
  f:close()
end

return M
