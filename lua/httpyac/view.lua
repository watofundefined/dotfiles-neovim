-- One reusable response split on the right.
local M = {}

local buf

local function ensure_buf()
  if buf and vim.api.nvim_buf_is_valid(buf) then return buf end
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close response" })
  return buf
end

-- r: result of cli.parse (success), meta: { env = string|nil }
function M.show(r, meta)
  local b = ensure_buf()
  local ft = require("httpyac.cli").filetype(r.headers)
  local body = r.body
  if ft == "json" then body = require("httpyac.cli").pretty_json(body) or body end
  vim.bo[b].modifiable = true
  vim.api.nvim_buf_set_lines(b, 0, -1, false, vim.split(body, "\n", { plain = true }))
  vim.bo[b].modifiable = false
  vim.bo[b].filetype = ft
  if ft ~= "text" then pcall(vim.treesitter.start, b) end

  local win = vim.fn.bufwinid(b)
  if win == -1 then
    local prev = vim.api.nvim_get_current_win()
    vim.cmd("botright vsplit")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, b)
    vim.api.nvim_set_current_win(prev)
  end
  local parts = { r.status .. " " .. (r.status_text or ""), r.name, meta.env, r.ms and (r.ms .. "ms") }
  vim.wo[win].winbar = " " .. table.concat(vim.tbl_filter(function(p) return p and p ~= "" end, parts), " · "):gsub("%%", "%%%%")
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

return M
