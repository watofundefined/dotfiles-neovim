-- Pure Lua: the block of text around a link line. See ADR-0001 "Preview".
local M = {}

local function blank(l)
  return l:match("^%s*$") ~= nil
end
local function heading(l)
  return l:match("^%s*#+%s") ~= nil or l:match("^%s*#+$") ~= nil
end
local function fence(l)
  return l:match("^%s*```") ~= nil or l:match("^%s*~~~") ~= nil
end
local function item(l)
  return l:match("^%s*[-*+]%s") ~= nil or l:match("^%s*%d+[.)]%s") ~= nil
end
local function indent(l)
  local ws = l:match("^%s*")
  return #ws:gsub("\t", "    ")
end
local function boundary(l)
  return blank(l) or heading(l) or fence(l)
end

--- Returns { start, finish, lines } (1-based, inclusive) for the block around
--- `lnum`, capped at `max` lines. When the block is longer than `max`, the window
--- is the first `max` lines, shifted down just enough to contain `lnum`.
function M.block(lines, lnum, max)
  max = max or 3
  local cur = lines[lnum]
  if cur == nil then
    return { start = lnum, finish = lnum, lines = {} }
  end
  if boundary(cur) then
    return { start = lnum, finish = lnum, lines = { cur } }
  end

  local start, base = lnum, nil
  if item(cur) then
    base = indent(cur)
  else
    local ci = indent(cur)
    local p = lnum - 1
    while p >= 1 do
      local l = lines[p]
      if boundary(l) then
        break
      end
      if item(l) then
        if indent(l) < ci then
          start, base = p, indent(l)
        end
        break
      end
      start = p
      p = p - 1
    end
    base = base or indent(lines[start])
  end

  local finish = lnum
  for i = lnum + 1, #lines do
    local l = lines[i]
    if boundary(l) or (item(l) and indent(l) <= base) then
      break
    end
    finish = i
  end

  local from = start
  if finish - start + 1 > max then
    if lnum > start + max - 1 then
      from = lnum - max + 1
    end
    finish = from + max - 1
  end
  local out = {}
  for i = from, finish do
    out[#out + 1] = lines[i]
  end
  return { start = from, finish = finish, lines = out }
end

return M
