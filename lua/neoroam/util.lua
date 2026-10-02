-- Pure Lua helpers: slugs, uuids, timestamps.
local M = {}

local groups = {
  a = "áàâäãåāăą", c = "çćčĉċ", d = "ďđ", e = "éèêëēĕėęě", g = "ğĝġģ", h = "ĥħ",
  i = "íìîïĩīĭįı", j = "ĵ", k = "ķ", l = "ĺļľŀł", n = "ñńņňŉ", o = "óòôöõōŏőø",
  r = "ŕŗř", s = "śŝşš", t = "ţťŧ", u = "úùûüũūŭůűų", w = "ŵ", y = "ýÿŷ", z = "źżž",
}
local upper = {
  A = "ÁÀÂÄÃÅĀĂĄ", C = "ÇĆČĈĊ", D = "ĎĐ", E = "ÉÈÊËĒĔĖĘĚ", G = "ĞĜĠĢ", H = "ĤĦ",
  I = "ÍÌÎÏĨĪĬĮİ", J = "Ĵ", K = "Ķ", L = "ĹĻĽĿŁ", N = "ÑŃŅŇ", O = "ÓÒÔÖÕŌŎŐØ",
  R = "ŔŖŘ", S = "ŚŜŞŠ", T = "ŢŤŦ", U = "ÚÙÛÜŨŪŬŮŰŲ", W = "Ŵ", Y = "ÝŸŶ", Z = "ŹŻŽ",
}
local UTF8CHAR = "[\192-\244][\128-\191]*"
local map = { ["ß"] = "ss", ["æ"] = "ae", ["Æ"] = "ae", ["œ"] = "oe", ["Œ"] = "oe", ["þ"] = "th" }
for ascii, chars in pairs(groups) do
  for ch in chars:gmatch(UTF8CHAR) do
    map[ch] = ascii
  end
end
for ascii, chars in pairs(upper) do
  for ch in chars:gmatch(UTF8CHAR) do
    map[ch] = ascii:lower()
  end
end

--- lowercase, spaces -> `_`, other non-alphanumerics dropped, Latin diacritics
--- mapped to ASCII; empty -> "untitled".
function M.slug(title)
  local s = title:gsub(UTF8CHAR, function(ch)
    return map[ch] or ""
  end)
  s = s:lower():gsub("%s+", "_"):gsub("[^%w_]", ""):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
  if s == "" then
    return "untitled"
  end
  return s
end

--- UUID v4 from 16 random bytes.
function M.uuid_from_bytes(bytes)
  local t = { bytes:byte(1, 16) }
  t[7] = t[7] % 16 + 64
  t[9] = t[9] % 64 + 128
  local hex = {}
  for i, b in ipairs(t) do
    hex[i] = string.format("%02x", b)
  end
  local h = table.concat(hex)
  return table.concat({ h:sub(1, 8), h:sub(9, 12), h:sub(13, 16), h:sub(17, 20), h:sub(21, 32) }, "-")
end

function M.file_stamp(time)
  return os.date("%Y%m%d%H%M%S", time)
end

function M.created_stamp(time)
  return os.date("%Y-%m-%dT%H:%M:%S", time)
end

return M
