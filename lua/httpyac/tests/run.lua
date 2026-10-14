-- Run: nvim --headless -u NONE -l lua/httpyac/tests/run.lua
local here = debug.getinfo(1, "S").source:sub(2):match("(.*)/")
package.path = here .. "/../../?.lua;" .. here .. "/../../?/init.lua;" .. package.path
local cli = require("httpyac.cli")

local failed, total = 0, 0
local function check(name, got, want)
  total = total + 1
  if not vim.deep_equal(got, want) then
    failed = failed + 1
    print("FAIL " .. name .. "\n  got:  " .. vim.inspect(got) .. "\n  want: " .. vim.inspect(want))
  end
end

check("args line+env", cli.build_args("a.http", { line = 3 }, "dev"),
  { "httpyac", "send", "a.http", "--json", "--line", "3", "-e", "dev" })
check("args all, no env", cli.build_args("a.http", { all = true }), { "httpyac", "send", "a.http", "--json", "--all" })

check("pretty", cli.pretty_json('{"a":[1,2],"b":{"c":null},"d":"x,{\\"y"}'),
  '{\n  "a": [\n    1,\n    2\n  ],\n  "b": {\n    "c": null\n  },\n  "d": "x,{\\"y"\n}')
check("pretty empty containers", cli.pretty_json('{"a":[],"b":{}}'), '{\n  "a": [],\n  "b": {}\n}')
check("pretty non-json", cli.pretty_json("hello"), nil)

local ok = vim.json.encode({ requests = { { name = "n", response = { statusCode = 200, statusMessage = "OK",
  headers = { ["content-type"] = "application/json" }, body = "{}", timings = { total = 5 } } } } })
check("parse ok", cli.parse(ok, ""), { name = "n", status = 200, status_text = "OK",
  headers = { ["content-type"] = "application/json" }, body = "{}", ms = 5 })
check("parse conn error", cli.parse(vim.json.encode({ requests = { { testResults = { { message = "ENOTFOUND" } } } } }), "").err, "ENOTFOUND")
check("parse empty stdout", cli.parse("", "boom\n").err, "boom")
check("parse nothing", cli.parse("", "").err, "No request found at cursor")

check("filetype json+charset", cli.filetype({ ["content-type"] = "application/problem+json; charset=utf-8" }), "json")
check("filetype none", cli.filetype({}), "text")
local t = os.time({ year = 2026, month = 10, day = 14, hour = 9, min = 5, sec = 7 })
check("filename json", cli.response_filename({ name = "Get user /1", headers = { ["content-type"] = "application/json" } }, t),
  "20261014090507-Get-user-1.json")
check("filename fallback", cli.response_filename({ headers = {} }, t), "20261014090507-response.txt")

-- env
do
  local env = require("httpyac.env")
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  local function write(name, data) local f = io.open(root .. "/" .. name, "w"); f:write(vim.json.encode(data)); f:close() end
  write("http-client.env.json", { ["$shared"] = { a = 1 }, dev = {}, prod = {} })
  write("http-client.private.env.json", { dev = {}, local_ = {} })
  check("env names", env.names(root), { "dev", "local_", "prod" })
  check("env root", env.root(root .. "/sub/x.http"), root)
  env.store = vim.fn.tempname() .. "/nested/env.json"
  check("env get unset", env.get(root), nil)
  env.set(root, "prod")
  env.set("/other", "dev")
  check("env roundtrip", { env.get(root), env.get("/other") }, { "prod", "dev" })
  vim.fn.delete(root, "rf")
end

print(string.format("%d checks, %d failed", total, failed))
os.exit(failed == 0 and 0 or 1)
