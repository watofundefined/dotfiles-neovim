-- Toggleable backlinks side buffer.
local config = require("neoroam.config")
local note = require("neoroam.note")
local render = require("neoroam.render")
local rg = require("neoroam.rg")
local scope = require("neoroam.scope")

local M = {}

local ns = vim.api.nvim_create_namespace("neoroam")

vim.api.nvim_set_hl(0, "NeoroamHeading", { link = "Title", default = true })
vim.api.nvim_set_hl(0, "NeoroamPath", { link = "Comment", default = true })
vim.api.nvim_set_hl(0, "NeoroamLink", { link = "Underlined", default = true })
vim.api.nvim_set_hl(0, "NeoroamCurrentLink", { bold = true, underline = true, default = true })

local S = { buf = nil, win = nil, seq = 0, job = nil, timer = nil, rows = {}, note_win = nil, group = nil }

local function valid_win()
  return S.win and vim.api.nvim_win_is_valid(S.win)
end

local function kill_job()
  if S.job then
    pcall(S.job.kill, S.job, 15)
    S.job = nil
  end
end

local function set_lines(lines, hl)
  if not (S.buf and vim.api.nvim_buf_is_valid(S.buf)) then
    return
  end
  vim.bo[S.buf].modifiable = true
  vim.api.nvim_buf_set_lines(S.buf, 0, -1, false, lines)
  vim.bo[S.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(S.buf, ns, 0, -1)
  for _, h in ipairs(hl or {}) do
    vim.api.nvim_buf_set_extmark(S.buf, ns, h[1], h[2], { end_col = h[3], hl_group = h[4] })
  end
end

local function show(view)
  S.rows = view.rows
  set_lines(view.lines, view.highlights)
end

-- Disk, not buffer: the hits' line numbers come from ripgrep, which reads disk.
local function load(path)
  return note.read_disk(path)
end

local function message(msg)
  show(render.message(msg))
end

local function do_refresh(src_buf, src_win)
  if not valid_win() or not scope.is_note_buf(src_buf) then
    return
  end
  if src_win and vim.api.nvim_win_is_valid(src_win) then
    S.note_win = src_win
  end
  local path = vim.api.nvim_buf_get_name(src_buf)
  local n = note.read(path)
  local fm = n.fm
  kill_job()
  S.seq = S.seq + 1
  local seq = S.seq
  if not (fm and fm.id) then
    return message("This note has no id yet (:NeoroamEnsureId).")
  end
  local dir = scope.dir(path)
  local title = n.title
  S.job = rg.backlinks(dir, fm.id, function(err, hits)
    if seq ~= S.seq then
      return -- superseded by a newer request
    end
    S.job = nil
    if err then
      return message("Error: " .. tostring(err))
    end
    show(render.build({
      title = title,
      id = fm.id,
      hits = hits,
      scope_dir = dir,
      preview_lines = config.get().preview_lines,
      load = load,
    }))
  end, path)
end

local function schedule_refresh(buf, win)
  if buf == S.buf or not valid_win() then
    return
  end
  if not scope.is_note_buf(buf) then
    return
  end
  S.timer = S.timer or vim.uv.new_timer()
  S.timer:stop()
  S.timer:start(
    config.get().debounce_ms,
    0,
    vim.schedule_wrap(function()
      do_refresh(buf, win)
    end)
  )
end

local function open_hit()
  local h = S.rows[vim.api.nvim_win_get_cursor(0)[1]]
  if not h then
    return
  end
  local win = S.note_win
  if not (win and vim.api.nvim_win_is_valid(win) and win ~= S.win) then
    win = nil
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if w ~= S.win then
        win = w
        break
      end
    end
  end
  if not win then
    vim.cmd("leftabove vsplit")
    win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_set_current_win(win)
  vim.cmd.edit(vim.fn.fnameescape(h.path))
  vim.api.nvim_win_set_cursor(0, { math.min(h.lnum, vim.api.nvim_buf_line_count(0)), 0 })
  vim.cmd("normal! zz")
end

function M.is_open()
  return valid_win()
end

function M.close()
  if valid_win() then
    vim.api.nvim_win_close(S.win, true)
  end
end

local function cleanup()
  kill_job()
  S.seq = S.seq + 1
  if S.timer then
    S.timer:stop()
    S.timer:close()
    S.timer = nil
  end
  if S.group then
    pcall(vim.api.nvim_del_augroup_by_id, S.group)
    S.group = nil
  end
  S.win, S.buf, S.rows = nil, nil, {}
end

function M.open()
  if valid_win() then
    return
  end
  local src_buf, src_win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  vim.cmd("botright " .. config.get().panel_width .. "vsplit")
  S.win = vim.api.nvim_get_current_win()
  S.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(S.win, S.buf)
  vim.bo[S.buf].buftype = "nofile"
  vim.bo[S.buf].bufhidden = "wipe"
  vim.bo[S.buf].swapfile = false
  vim.bo[S.buf].filetype = "neoroam"
  vim.b[S.buf].neoroam_panel = true
  vim.bo[S.buf].modifiable = false
  for k, v in pairs({ number = false, relativenumber = false, signcolumn = "no", wrap = true, winfixwidth = true, cursorline = true }) do
    vim.wo[S.win][k] = v
  end
  vim.keymap.set("n", "<CR>", open_hit, { buffer = S.buf, desc = "Open backlink source" })
  vim.keymap.set("n", "q", M.close, { buffer = S.buf, desc = "Close backlinks" })
  vim.keymap.set("n", "r", function()
    do_refresh(S.last_buf or src_buf, S.note_win)
  end, { buffer = S.buf, desc = "Refresh backlinks" })

  S.group = vim.api.nvim_create_augroup("neoroam_panel", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = S.group,
    callback = function(a)
      S.last_buf = scope.is_note_buf(a.buf) and a.buf or S.last_buf
      schedule_refresh(a.buf, vim.api.nvim_get_current_win())
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = S.group,
    pattern = tostring(S.win),
    once = true,
    callback = cleanup,
  })

  vim.api.nvim_set_current_win(src_win)
  S.note_win = src_win
  S.last_buf = src_buf
  if scope.is_note_buf(src_buf) then
    do_refresh(src_buf, src_win)
  else
    message("Not a note in scope.")
  end
end

function M.toggle()
  if valid_win() then
    M.close()
  else
    M.open()
  end
end

return M
