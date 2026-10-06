-- Where notes live: <git root of the buffer, else cwd>[/<notes_root>].
-- Tested on macOS. Paths are compared with "/" separators and case-sensitively,
-- so on Windows (backslashes from fs_realpath, drive-letter case) notes may not be detected.
local config = require("neoroam.config")

local M = {}

local function real(p)
  return vim.uv.fs_realpath(p) or vim.fs.normalize(p)
end

function M.root(path)
  local start = (path and path ~= "") and vim.fs.dirname(path) or vim.uv.cwd()
  local git = vim.fs.root(start, ".git")
  return real(git or vim.uv.cwd())
end

--- Absolute directory all note operations are restricted to.
function M.dir(path)
  local root = M.root(path)
  local nr = config.get().notes_root
  if nr then
    return real(root .. "/" .. nr) -- falls back to the joined path if missing
  end
  return root
end

function M.in_scope(path)
  if not path or path == "" then
    return false
  end
  local dir = M.dir(path)
  local p = real(path)
  return p:sub(1, #dir + 1) == dir .. "/"
end

function M.is_note_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype ~= "markdown" then
    return false
  end
  return M.in_scope(vim.api.nvim_buf_get_name(buf))
end

return M
