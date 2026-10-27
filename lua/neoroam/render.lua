-- Pure Lua: text of the Backlinks panel. `build` is the interface; disk is reached only through `load`.
local links = require("neoroam.links")
local preview = require("neoroam.preview")

local PREFIX = "│ "

local M = {}

--- One preview line as shown in the panel: ids are noise, so `[text](id:uuid)`
--- becomes `[text]`. Returns the text and highlight spans { start, finish, kind }
--- (0-based, end-exclusive byte columns); kind is "current" for links to
--- `current_id`, else "link".
local function preview_line(line, current_id)
  local out, spans, pos, len = {}, {}, 1, 0
  current_id = current_id and current_id:lower()
  local function push(str)
    out[#out + 1] = str
    len = len + #str
  end
  for _, l in ipairs(links.find_all(line)) do
    push(line:sub(pos, l.start - 1))
    local shown = "[" .. line:sub(l.start + 1, l.finish - 42) .. "]"
    spans[#spans + 1] = { len, len + #shown, l.id == current_id and "current" or "link" }
    push(shown)
    pos = l.finish + 1
  end
  push(line:sub(pos))
  local text = table.concat(out)
  local trimmed = text:gsub("%s+$", "")
  return trimmed, spans
end
M.preview_line = preview_line

--- A one-line screen (empty, error, not-a-note). Same shape as `build`.
function M.message(msg)
  return { lines = { msg }, highlights = { { 0, 0, #msg, "NeoroamPath" } }, rows = {} }
end

--- opts: { title, id, hits = { {path, lnum} }, scope_dir, preview_lines,
---         load = function(path) -> { title, lines } | nil }
--- Returns { lines, highlights = { {row0, col0, col1, group} }, rows = { [line] = hit } }.
function M.build(opts)
  local by_path, order = {}, {}
  for _, h in ipairs(opts.hits) do
    if not by_path[h.path] then
      local src = opts.load(h.path) or { title = h.path, lines = {} }
      by_path[h.path] = { path = h.path, title = src.title, lines = src.lines, hits = {} }
      order[#order + 1] = by_path[h.path]
    end
    table.insert(by_path[h.path].hits, h)
  end
  table.sort(order, function(a, b)
    if a.title:lower() ~= b.title:lower() then
      return a.title:lower() < b.title:lower()
    end
    return a.path < b.path
  end)

  local lines, hl, rows = {}, {}, {}
  -- spans: { start, finish, group } byte columns; `group` alone highlights the whole line
  local function add(text, group, row, spans, offset)
    lines[#lines + 1] = text
    rows[#lines] = row
    if group then
      hl[#hl + 1] = { #lines - 1, 0, #text, group }
    end
    for _, sp in ipairs(spans or {}) do
      hl[#hl + 1] = { #lines - 1, sp[1] + offset, sp[2] + offset, sp[3] }
    end
  end
  add(string.format("Backlinks: %s (%d)", opts.title, #opts.hits), "NeoroamHeading")
  for _, g in ipairs(order) do
    table.sort(g.hits, function(a, b)
      return a.lnum < b.lnum
    end)
    add("")
    add(g.title, "NeoroamHeading", g.hits[1])
    add(g.path:sub(#opts.scope_dir + 2), "NeoroamPath", g.hits[1])
    for _, h in ipairs(g.hits) do
      local b = preview.block(g.lines, h.lnum, opts.preview_lines)
      add("", nil, h)
      add(string.format("line %d", h.lnum), "NeoroamPath", h)
      for _, l in ipairs(b.lines) do
        local text, spans = preview_line(l, opts.id)
        for _, sp in ipairs(spans) do
          sp[3] = sp[3] == "current" and "NeoroamCurrentLink" or "NeoroamLink"
        end
        add(PREFIX .. text, nil, h, spans, #PREFIX)
        hl[#hl + 1] = { #lines - 1, 0, #PREFIX, "NeoroamPath" }
      end
    end
  end
  if #opts.hits == 0 then
    add("")
    add("No backlinks.", "NeoroamPath")
  end
  return { lines = lines, highlights = hl, rows = rows }
end

return M
