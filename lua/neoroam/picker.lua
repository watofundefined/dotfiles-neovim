-- Telescope picker that inserts an id link. Telescope is required lazily.
local M = {}

function M.insert()
  local ok_t, pickers = pcall(require, "telescope.pickers")
  if not ok_t then
    return require("neoroam.notes").notify("telescope.nvim is required for the picker", vim.log.levels.ERROR)
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local rg = require("neoroam.rg")
  local scope = require("neoroam.scope")

  local origin = vim.api.nvim_get_current_win()
  local dir = scope.dir(vim.api.nvim_buf_get_name(0))

  pickers
    .new({}, {
      prompt_title = "Insert note link",
      finder = finders.new_table({
        results = rg.files(dir),
        entry_maker = function(path)
          local rel = path:sub(#dir + 2)
          local title = rg.title_of(path)
          return { value = path, display = title .. "  " .. rel, ordinal = title .. " " .. rel, path = path }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.file_previewer({}),
      attach_mappings = function(bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(bufnr)
          if not entry then
            return
          end
          vim.schedule(function()
            if vim.api.nvim_win_is_valid(origin) then
              vim.api.nvim_set_current_win(origin)
            end
            require("neoroam.notes").insert_link(entry.path)
          end)
        end)
        return true
      end,
    })
    :find()
end

return M
