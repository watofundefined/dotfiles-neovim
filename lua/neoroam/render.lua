-- Pure Lua: text of the backlinks panel.
local links = require("neoroam.links")

local M = {}

--- One preview line as shown in the panel: ids are noise, so `[text](id:uuid)`
--- becomes `[text]`. Returns the text and highlight spans { start, finish, kind }
--- (0-based, end-exclusive byte columns); kind is "current" for links to
--- `current_id`, else "link".
function M.preview_line(line, current_id)
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

return M
