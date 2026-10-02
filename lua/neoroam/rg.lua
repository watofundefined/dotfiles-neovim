-- ripgrep-backed lookups. No index: everything is computed on demand (ADR-0001).
local frontmatter = require("neoroam.frontmatter")

local M = {}

local BASE = { "rg", "--json", "--no-messages", "--no-require-git", "-g", "*.md" }

--- Parse `rg --json` stdout into { path, lnum, text } for each match.
function M.parse_json(stdout)
  local hits = {}
  for line in (stdout or ""):gmatch("[^\n]+") do
    local ok, d = pcall(vim.json.decode, line)
    if ok and type(d) == "table" and d.type == "match" then
      local data = d.data
      if data.path and data.path.text and data.lines and data.lines.text then
        hits[#hits + 1] = {
          path = data.path.text,
          lnum = data.line_number,
          text = (data.lines.text:gsub("\r?\n$", "")),
        }
      end
    end
  end
  return hits
end

local function run(args, cb)
  local ok, obj = pcall(vim.system, args, { text = true }, vim.schedule_wrap(function(res)
    if res.signal ~= 0 then
      return cb("killed", nil)
    end
    if res.code > 1 and (res.stdout or "") == "" then
      return cb(vim.trim(res.stderr or "") ~= "" and res.stderr or "rg exited with " .. res.code, nil)
    end
    cb(nil, M.parse_json(res.stdout))
  end))
  if not ok then
    vim.schedule(function()
      cb("cannot run ripgrep: " .. tostring(obj), nil)
    end)
    return nil
  end
  return obj
end

local function cmd(extra, scope)
  local args = vim.list_extend({}, BASE)
  vim.list_extend(args, extra)
  args[#args + 1] = scope
  return args
end

--- Hits for every `](id:<id>)` under `scope`, one per source line.
--- cb(err, hits). Returns the process handle (use :kill()).
function M.backlinks(scope, id, cb)
  return run(cmd({ "-F", "-i", "-e", "](id:" .. id .. ")" }, scope), function(err, hits)
    if err then
      return cb(err)
    end
    local seen, out = {}, {}
    for _, h in ipairs(hits) do
      local key = h.path .. ":" .. h.lnum
      if not seen[key] then
        seen[key] = true
        out[#out + 1] = h
      end
    end
    cb(nil, out)
  end)
end

--- Files whose frontmatter declares `id: <id>`. cb(err, paths); more than one
--- path means a duplicate id.
function M.find_by_id(scope, id, cb)
  local pat = "^id:\\s*['\"]?" .. id .. "['\"]?\\s*$"
  return run(cmd({ "-i", "-m1", "-e", pat }, scope), function(err, hits)
    if err then
      return cb(err)
    end
    local seen, paths = {}, {}
    for _, h in ipairs(hits) do
      if not seen[h.path] then
        seen[h.path] = true
        local lines = vim.fn.readfile(h.path)
        local fm = frontmatter.parse(lines)
        if fm and fm.id == id:lower() and h.lnum >= 2 and h.lnum < fm.last then
          paths[#paths + 1] = h.path
        end
      end
    end
    table.sort(paths)
    cb(nil, paths)
  end)
end

--- Every note in scope (sync).
function M.files(scope)
  local res = vim.system({ "rg", "--files", "--no-messages", "--no-require-git", "-g", "*.md", scope }, { text = true }):wait()
  local out = {}
  for l in (res.stdout or ""):gmatch("[^\n]+") do
    out[#out + 1] = l
  end
  table.sort(out)
  return out
end

--- Title of the note at `path`: frontmatter `title:` or the filename fallback.
function M.title_of(path)
  local ok, lines = pcall(vim.fn.readfile, path, "", 100)
  return frontmatter.title(ok and frontmatter.parse(lines) or nil, path)
end

return M
