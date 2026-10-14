-- Pure helpers: build the httpyac argv and parse its --json output.
local M = {}

-- target: { line = N } (1-based, request containing that line) or { all = true }
function M.build_args(file, target, env)
  local args = { "httpyac", "send", file, "--json" }
  if target.all then
    table.insert(args, "--all")
  else
    vim.list_extend(args, { "--line", tostring(target.line) })
  end
  if env then vim.list_extend(args, { "-e", env }) end
  return args
end

-- Returns { name, status, status_text, headers, body, ms } or { err = "..." }.
-- shortcut: only the first request is read, when :HttpRunAll lands iterate `requests`.
function M.parse(stdout, stderr)
  local ok, data = pcall(vim.json.decode, stdout or "")
  local req = ok and type(data) == "table" and data.requests and data.requests[1]
  if not req then
    local msg = vim.trim(stderr or "")
    return { err = msg ~= "" and msg or "No request found at cursor" }
  end
  local r = req.response
  if not r then
    local t = req.testResults and req.testResults[1]
    return { err = (t and t.message) or "Request failed" }
  end
  return {
    name = req.name,
    status = r.statusCode,
    status_text = r.statusMessage,
    headers = r.headers or {},
    body = type(r.body) == "string" and r.body or "",
    ms = r.timings and r.timings.total,
  }
end

-- Filetype for a response, from its Content-Type header.
function M.filetype(headers)
  local ct = (headers["content-type"] or ""):lower()
  for _, ft in ipairs({ "json", "html", "xml" }) do
    if ct:find(ft, 1, true) then return ft end
  end
  return "text"
end

-- "YYYYMMDDHHMMSS-<request-name>.<ext>" for a saved response; `time` is os.time().
function M.response_filename(r, time)
  local ft = M.filetype(r.headers)
  local short = (r.name or ""):gsub("[^%w_-]+", "-"):gsub("^-+", ""):gsub("-+$", ""):sub(1, 40)
  if short == "" then short = "response" end
  return os.date("%Y%m%d%H%M%S", time) .. "-" .. short .. "." .. (ft == "text" and "txt" or ft)
end

-- Re-indent a JSON string without decoding (keeps key order). Returns nil if it is not JSON.
function M.pretty_json(s)
  if not s:match("^%s*[%[{]") then return nil end
  local out, depth, in_str, esc = {}, 0, false, false
  local function nl() out[#out + 1] = "\n" .. ("  "):rep(depth) end
  for c in s:gmatch(".") do
    if in_str then
      out[#out + 1] = c
      if esc then esc = false elseif c == "\\" then esc = true elseif c == '"' then in_str = false end
    elseif c == '"' then
      in_str = true
      out[#out + 1] = c
    elseif c == "{" or c == "[" then
      out[#out + 1] = c
      depth = depth + 1
      nl()
    elseif c == "}" or c == "]" then
      depth = depth - 1
      nl()
      out[#out + 1] = c
    elseif c == "," then
      out[#out + 1] = c
      nl()
    elseif c == ":" then
      out[#out + 1] = ": "
    elseif not c:match("%s") then
      out[#out + 1] = c
    end
  end
  -- collapse empty containers produced above: "{\n}" -> "{}"
  local res = table.concat(out):gsub("([%[{])\n%s*([%]}])", "%1%2")
  return res
end

return M
