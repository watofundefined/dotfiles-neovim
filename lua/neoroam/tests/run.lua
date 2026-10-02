-- Run: nvim --headless -u NONE -l lua/neoroam/tests/run.lua
-- Fixtures in ./fixtures are the language-neutral contract (ADR-0001).
local here = debug.getinfo(1, "S").source:sub(2):match("(.*)/") -- .../lua/neoroam/tests
local lua_root = here .. "/../.."
package.path = lua_root .. "/?.lua;" .. lua_root .. "/?/init.lua;" .. package.path
vim.opt.rtp:prepend(lua_root .. "/..")

local fx = here .. "/fixtures"
local frontmatter = require("neoroam.frontmatter")
local preview = require("neoroam.preview")
local links = require("neoroam.links")
local util = require("neoroam.util")

local failed, total = 0, 0
local function check(name, got, want)
  total = total + 1
  if not vim.deep_equal(got, want) then
    failed = failed + 1
    print("FAIL " .. name .. "\n  got:  " .. vim.inspect(got) .. "\n  want: " .. vim.inspect(want))
  end
end
local function read(p)
  return vim.fn.readfile(p)
end
local function json(p)
  return vim.json.decode(table.concat(read(p), "\n"), { luanil = { object = true, array = true } })
end
local function cases(dir)
  local names = {}
  for name in vim.fs.dir(fx .. "/" .. dir) do
    local n = name:match("^(.*)%.md$")
    if n then
      names[#names + 1] = n
    end
  end
  table.sort(names)
  return names
end

-- frontmatter
for _, n in ipairs(cases("frontmatter")) do
  local want = json(fx .. "/frontmatter/" .. n .. ".json")
  local fm = frontmatter.parse(read(fx .. "/frontmatter/" .. n .. ".md"))
  local got = { frontmatter = fm ~= nil }
  if fm then
    got.id, got.title, got.created = fm.id, fm.title, fm.created
  end
  check("frontmatter/" .. n, got, want)
end
for _, t in ipairs(json(fx .. "/titles.json")) do
  check("title " .. t.path, frontmatter.title_from_path(t.path), t.title)
end

-- id insertion
do
  local lines = { "---", "title: T", "---", "body" }
  check("insert_id existing fm", frontmatter.insert_id(lines, "X"), { "---", "id: X", "title: T", "---", "body" })
  check("insert_id no fm", frontmatter.insert_id({ "body" }, "X"), { "---", "id: X", "---", "", "body" })
  check("insert_id crlf", frontmatter.insert_id({ "body\r" }, "X"), { "---\r", "id: X\r", "---\r", "\r", "body\r" })
  check("insert_id bom", frontmatter.insert_id({ "\239\187\191body" }, "X")[1], "\239\187\191---")
end

-- preview
for _, n in ipairs(cases("preview")) do
  local want = json(fx .. "/preview/" .. n .. ".json")
  local lines = read(fx .. "/preview/" .. n .. ".md")
  local b = preview.block(lines, want.line, want.max)
  check("preview/" .. n, { start = b.start, finish = b.finish }, { start = want.start, finish = want.finish })
  check("preview/" .. n .. " lines", #b.lines, want.finish - want.start + 1)
end

-- links
for _, n in ipairs(cases("links")) do
  local want = json(fx .. "/links/" .. n .. ".json")
  local line = read(fx .. "/links/" .. n .. ".md")[1]
  check("links/" .. n, links.find_all(line), want.links)
  for _, c in ipairs(want.at_col or {}) do
    local l = links.at_col(line, c.col)
    check("links/" .. n .. " at_col " .. c.col, l and l.id or nil, c.id)
  end
end
check("format escapes", links.format("a [b]", "X"), "[a \\[b\\]](id:X)")

-- util
for _, s in ipairs(json(fx .. "/slugs.json")) do
  check("slug '" .. s.title .. "'", util.slug(s.title), s.slug)
end
do
  local u = json(fx .. "/uuid.json")
  check("uuid zeros", util.uuid_from_bytes(string.rep("\0", 16)), u.uuid)
  check("uuid ff", util.uuid_from_bytes(string.rep("\255", 16)), u.uuid_ff)
  check("uuid random shape", links.is_uuid(util.uuid_from_bytes(vim.uv.random(16))), true)
end

-- ripgrep (async API driven synchronously)
local rg = require("neoroam.rg")
local vault = vim.uv.fs_realpath(fx .. "/vault")
local function await(start)
  local done, err, res
  start(function(e, r)
    done, err, res = true, e, r
  end)
  vim.wait(5000, function()
    return done
  end, 10)
  return err, res
end
local A = "620b6220-a3b9-44b4-970e-b6d221fa1dca"
do
  local err, hits = await(function(cb)
    rg.backlinks(vault, A, cb)
  end)
  local names = {}
  for _, h in ipairs(hits or {}) do
    names[#names + 1] = h.path:sub(#vault + 2) .. ":" .. h.lnum
  end
  table.sort(names)
  check("backlinks", { err, names }, {
    nil,
    {
      "20240102000000-bullets.md:5",
      "20240108000000-noid.md:2",
      "People/20240103000000-upper.md:4",
    },
  })
end
do
  local _, paths = await(function(cb)
    rg.find_by_id(vault, A, cb)
  end)
  check("find_by_id single", vim.tbl_map(function(p) return p:sub(#vault + 2) end, paths), { "20240101000000-target.md" })
  local _, dups = await(function(cb)
    rg.find_by_id(vault, "dddddddd-dddd-4ddd-8ddd-dddddddddddd", cb)
  end)
  check("find_by_id duplicates", #dups, 2)
  local _, c = await(function(cb)
    rg.find_by_id(vault, "cccccccc-cccc-4ccc-8ccc-cccccccccccc", cb)
  end)
  check("find_by_id ignores body-only match", vim.tbl_map(function(p) return p:sub(#vault + 2) end, c), { "20240106000000-realc.md" })
  local _, q = await(function(cb)
    rg.find_by_id(vault, "abababab-abab-4bab-8bab-abababababab", cb)
  end)
  check("find_by_id quoted id", #q, 1)
  local _, none = await(function(cb)
    rg.find_by_id(vault, "00000000-0000-4000-8000-00000000000a", cb)
  end)
  check("find_by_id none", #none, 0)
end

print(string.format("%d checks, %d failed", total, failed))
os.exit(failed == 0 and 0 or 1)
