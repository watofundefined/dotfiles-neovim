-- A Note's identity: id and title, read from the loaded buffer or from disk. See GLOSSARY.md.
local frontmatter = require("neoroam.frontmatter")
local util = require("neoroam.util")

local M = {}

function M.notify(msg, level)
  vim.notify("neoroam: " .. msg, level or vim.log.levels.INFO)
end

function M.new_uuid()
  return util.uuid_from_bytes(vim.uv.random(16))
end

local function loaded_buf(path)
  local want = vim.fs.normalize(path)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(b)
    if vim.api.nvim_buf_is_loaded(b) and name ~= "" and vim.fs.normalize(name) == want then
      return b
    end
  end
end

local function from_lines(path, lines)
  local fm = frontmatter.parse(lines)
  return { id = fm and fm.id, title = frontmatter.title(fm, path), fm = fm, lines = lines }
end

--- What the file on disk says (what ripgrep sees). `max` caps the lines read.
--- Returns { id, title, fm, lines }; `lines` is empty when the file is unreadable.
function M.read_disk(path, max)
  local ok, lines
  if max then
    ok, lines = pcall(vim.fn.readfile, path, "", max)
  else
    ok, lines = pcall(vim.fn.readfile, path)
  end
  return from_lines(path, ok and lines or {})
end

--- What the note says right now: the loaded buffer (unsaved edits included), else disk.
function M.read(path)
  local buf = loaded_buf(path)
  if buf then
    return from_lines(path, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  end
  return M.read_disk(path)
end

--- Returns (id, title) of the note at `path`, adding an `id` first if it lacks one.
--- A loaded buffer is edited (and written if it was unmodified); otherwise the file is.
function M.ensure_id(path)
  local n = M.read(path)
  if n.id then
    return n.id, n.title
  end
  local id = M.new_uuid()
  local buf = loaded_buf(path)
  if buf then
    local was_modified = vim.bo[buf].modified
    local idx, ins = frontmatter.id_insertion(n.lines, id)
    vim.api.nvim_buf_set_lines(buf, idx, idx, false, ins)
    if not was_modified then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("silent write")
      end)
    end
  else
    vim.fn.writefile(frontmatter.insert_id(n.lines, id), path)
  end
  M.notify("added id to " .. path)
  return id, n.title
end

return M
