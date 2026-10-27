-- Note-level operations: ids, link insertion, creation.
local links = require("neoroam.links")
local util = require("neoroam.util")
local scope = require("neoroam.scope")

local M = {}

local note = require("neoroam.note")
local notify = note.notify
M.notify = notify

--- Add an id to the current note if it lacks one.
function M.ensure_current_id()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    return notify("buffer has no file", vim.log.levels.WARN)
  end
  local n = note.read(path)
  if n.id then
    return notify("note already has id " .. n.id)
  end
  note.ensure_id(path)
end

--- Insert `[title](id:uuid)` for the note at `path` after the cursor of the current window.
function M.insert_link(path)
  local id, title = note.ensure_id(path)
  vim.api.nvim_put({ links.format(title, id) }, "c", true, true)
end

--- Follow the id link under the cursor.
function M.follow()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local link = links.at_col(line, col)
  if not link then
    return notify("no id link under cursor", vim.log.levels.WARN)
  end
  local dir = scope.dir(vim.api.nvim_buf_get_name(0))
  require("neoroam.rg").find_by_id(dir, link.id, function(err, paths)
    if err then
      return notify(err, vim.log.levels.ERROR)
    end
    if #paths == 0 then
      return notify("no note with id " .. link.id, vim.log.levels.WARN)
    end
    local function open(path)
      vim.cmd.edit(vim.fn.fnameescape(path))
    end
    if #paths > 1 then
      notify("duplicate id " .. link.id, vim.log.levels.WARN)
      return vim.ui.select(paths, { prompt = "Duplicate id, open:" }, function(choice)
        if choice then
          open(choice)
        end
      end)
    end
    open(paths[1])
  end)
end

local function subfolders(dir)
  local out = {}
  local handle = vim.uv.fs_scandir(dir)
  while handle do
    local name, typ = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if typ == "directory" and name:sub(1, 1) ~= "." then
      out[#out + 1] = name
    end
  end
  table.sort(out)
  return out
end

local function create(dir, folder, title)
  local target = folder and (dir .. "/" .. folder) or dir
  vim.fn.mkdir(target, "p")
  local now = os.time()
  local path = string.format("%s/%s-%s.md", target, util.file_stamp(now), util.slug(title))
  local content = table.concat({
    "---",
    "id: " .. note.new_uuid(),
    "title: " .. title,
    "created: " .. util.created_stamp(now),
    "---",
    "",
    "",
  }, "\n")
  local fd = vim.uv.fs_open(path, "wx", 420) -- 0644; "x" never overwrites
  if not fd then
    return notify("refusing to overwrite existing " .. path, vim.log.levels.ERROR)
  end
  vim.uv.fs_write(fd, content)
  vim.uv.fs_close(fd)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.cmd("normal! G")
  vim.cmd("startinsert")
end

--- Pick a folder (only if the notes root has sub-folders), then a title.
--- <Esc>, <C-c> or an empty title cancels.
function M.new()
  local dir = scope.dir(vim.api.nvim_buf_get_name(0))

  local function ask_title(folder)
    local where = folder and (folder .. "/") or ""
    vim.ui.input({ prompt = "Note title (" .. where .. ", <Esc> or empty to cancel): " }, function(input)
      local title = input and vim.trim(input) or ""
      if title == "" then
        return notify("new note cancelled")
      end
      create(dir, folder, title)
    end)
  end

  local subs = subfolders(dir)
  if #subs == 0 then
    return ask_title(nil)
  end
  local choices = vim.list_extend({ "(top level)" }, subs)
  vim.ui.select(choices, { prompt = "Folder:" }, function(choice)
    if not choice then
      return notify("new note cancelled")
    end
    ask_title(choice ~= "(top level)" and choice or nil)
  end)
end

return M
