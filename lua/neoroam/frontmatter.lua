-- Pure Lua (no vim.api): frontmatter parsing and id insertion. See ADR-0001.
local M = {}

local BOM = "\239\187\191"
local FENCE = "^%-%-%-%s*$"

local function clean(line)
  return (line:gsub("\r$", ""))
end

local function unquote(v)
  local q = v:sub(1, 1)
  if (q == '"' or q == "'") and #v >= 2 and v:sub(-1) == q then
    return v:sub(2, -2)
  end
  return v
end

--- Parse the `---` fenced block at the very start of `lines`.
--- Returns nil when there is none, else { id, title, created, last } where `last`
--- is the 1-based line of the closing fence. `id` is lowercased.
function M.parse(lines)
  if #lines == 0 then
    return nil
  end
  local first = clean(lines[1])
  if first:sub(1, 3) == BOM then
    first = first:sub(4)
  end
  if not first:match(FENCE) then
    return nil
  end
  local fm = {}
  for i = 2, #lines do
    local line = clean(lines[i])
    if line:match(FENCE) then
      fm.last = i
      if fm.id then
        fm.id = fm.id:lower()
      end
      return fm
    end
    local key, value = line:match("^([%w_-]+)%s*:%s*(.-)%s*$")
    if key and (key == "id" or key == "title" or key == "created") and fm[key] == nil then
      value = unquote(value)
      if value ~= "" then
        fm[key] = value
      end
    end
  end
  return nil
end

--- Filename fallback: no `.md`, no leading 14-digit timestamp, `_` -> space.
function M.title_from_path(path)
  local name = path:match("[^/\\]*$")
  name = name:gsub("%.md$", ""):gsub("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%-", ""):gsub("_", " ")
  return name
end

--- Frontmatter title, else filename fallback.
function M.title(fm, path)
  if fm and fm.title then
    return fm.title
  end
  return M.title_from_path(path)
end

--- Where to put `id: <id>`: returns (index, new_lines), index 0-based for
--- nvim_buf_set_lines(buf, index, index, false, new_lines).
function M.id_insertion(lines, id)
  local cr = (lines[1] or ""):sub(-1) == "\r" and "\r" or ""
  local fm = M.parse(lines)
  if fm then
    return 1, { "id: " .. id .. cr }
  end
  return 0, { "---" .. cr, "id: " .. id .. cr, "---" .. cr, cr }
end

--- Full-file variant (for files that are not loaded); keeps a BOM at file start.
function M.insert_id(lines, id)
  local idx, ins = M.id_insertion(lines, id)
  local out = {}
  for i, l in ipairs(lines) do
    out[i] = l
  end
  if idx == 0 and out[1] and out[1]:sub(1, 3) == BOM then
    out[1] = out[1]:sub(4)
    ins[1] = BOM .. ins[1]
  end
  for i, l in ipairs(ins) do
    table.insert(out, idx + i, l)
  end
  return out
end

return M
