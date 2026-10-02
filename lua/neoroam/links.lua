-- Pure Lua: `[text](id:<uuid>)` links.
local M = {}

local UUID = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

function M.is_uuid(s)
  return s:match(UUID) ~= nil
end

--- All links in `line`: { start, finish (1-based, inclusive byte cols), text, id }.
--- `text` is unescaped (`\[` `\]`), `id` lowercased.
function M.find_all(line)
  local out = {}
  local i = 1
  while true do
    local open = line:find("[", i, true)
    if not open then
      break
    end
    local j, close = open + 1, nil
    while j <= #line do
      local c = line:sub(j, j)
      if c == "\\" then
        j = j + 2
      elseif c == "]" then
        close = j
        break
      else
        j = j + 1
      end
    end
    local matched = false
    if close and line:sub(close + 1, close + 4) == "(id:" then
      local uuid = line:sub(close + 5, close + 40)
      if M.is_uuid(uuid) and line:sub(close + 41, close + 41) == ")" then
        out[#out + 1] = {
          start = open,
          finish = close + 41,
          text = (line:sub(open + 1, close - 1):gsub("\\([%[%]])", "%1")),
          id = uuid:lower(),
        }
        i = close + 42
        matched = true
      end
    end
    if not matched then
      i = open + 1
    end
  end
  return out
end

--- The link whose span contains 0-based byte column `col`, or nil.
function M.at_col(line, col)
  for _, l in ipairs(M.find_all(line)) do
    if col + 1 >= l.start and col + 1 <= l.finish then
      return l
    end
  end
  return nil
end

function M.format(title, id)
  return "[" .. title:gsub("([%[%]])", "\\%1") .. "](id:" .. id .. ")"
end

return M
