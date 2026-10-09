local builtin = require("telescope.builtin")

local keymap = vim.keymap.set

local function close_other_buffers()
    local current = vim.api.nvim_get_current_buf()
    local skipped = {}
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[bufnr].buflisted and bufnr ~= current then
            local ok = pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
            if not ok then
                table.insert(skipped, vim.api.nvim_buf_get_name(bufnr))
            end
        end
    end
    if #skipped > 0 then
        vim.notify("close_other_buffers: skipped unsaved buffer(s):\n" .. table.concat(skipped, "\n"), vim.log.levels.WARN)
    end
end

local is_win = vim.fn.has("win32") == 1
local is_mac = vim.fn.has("mac") == 1
local trash_name = is_win and "Recycle Bin" or "Trash"

-- Returns the command that moves `path` to the OS trash, or nil if none is available.
local function trash_cmd(path)
    if is_win then
        local ps_cmd = string.format(
            "Add-Type -AssemblyName Microsoft.VisualBasic; " ..
            "[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('%s', 'OnlyErrorDialogs', 'SendToRecycleBin')",
            (path:gsub("'", "''"))
        )
        return { "powershell", "-NoProfile", "-NonInteractive", "-Command", ps_cmd }
    end
    if is_mac then
        if vim.fn.executable("trash") == 1 then -- built in since macOS 14
            return { "trash", path }
        end
        local escaped = path:gsub("\\", "\\\\"):gsub('"', '\\"')
        return { "osascript", "-e", string.format('tell application "Finder" to delete POSIX file "%s"', escaped) }
    end
    if vim.fn.executable("gio") == 1 then
        return { "gio", "trash", path }
    end
    if vim.fn.executable("trash-put") == 1 then
        return { "trash-put", path }
    end
    if vim.fn.executable("kioclient") == 1 then
        return { "kioclient", "move", path, "trash:/" }
    end
    return nil
end

local function delete_file_to_trash()
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == "" then
        vim.notify("delete_file_to_trash: buffer has no file", vim.log.levels.WARN)
        return
    end

    local choice = vim.fn.confirm(
        "Delete '" .. vim.fn.fnamemodify(filepath, ":t") .. "' and send to " .. trash_name .. "?",
        "&Yes\n&No",
        2
    )
    if choice ~= 1 then
        return
    end

    local cmd = trash_cmd(filepath)
    if cmd then
        local result = vim.fn.system(cmd)
        if vim.v.shell_error ~= 0 then
            vim.notify("Failed to delete file:\n" .. result, vim.log.levels.ERROR)
            return
        end
    else
        local permanent = vim.fn.confirm("No trash command found. Delete '" .. vim.fn.fnamemodify(filepath, ":t") .. "' permanently?", "&Yes\n&No", 2)
        if permanent ~= 1 then
            return
        end
        local ok, err = os.remove(filepath)
        if not ok then
            vim.notify("Failed to delete file:\n" .. tostring(err), vim.log.levels.ERROR)
            return
        end
    end

    vim.cmd("bdelete!")
    vim.notify("Deleted" .. (cmd and (" (sent to " .. trash_name .. ")") or " permanently") .. ": " .. filepath, vim.log.levels.INFO)
end

local function rename_file()
    local old_path = vim.api.nvim_buf_get_name(0)
    if old_path == "" then
        vim.notify("rename_file: buffer has no file", vim.log.levels.WARN)
        return
    end

    local dir = vim.fn.fnamemodify(old_path, ":h")
    local old_name = vim.fn.fnamemodify(old_path, ":t")

    vim.ui.input({ prompt = "New filename: ", default = old_name }, function(new_name)
        if not new_name or new_name == "" or new_name == old_name then
            return
        end

        local new_path = dir .. "/" .. new_name
        if vim.loop.fs_stat(new_path) then
            vim.notify("rename_file: '" .. new_name .. "' already exists", vim.log.levels.ERROR)
            return
        end

        local ok, err = os.rename(old_path, new_path)
        if not ok then
            vim.notify("rename_file: failed to rename file:\n" .. tostring(err), vim.log.levels.ERROR)
            return
        end

        local old_bufnr = vim.api.nvim_get_current_buf()
        vim.cmd("edit " .. vim.fn.fnameescape(new_path))
        vim.api.nvim_buf_delete(old_bufnr, { force = true })
        vim.notify("Renamed to: " .. new_path, vim.log.levels.INFO)
    end)
end

local function run_git_action(action)
    local filename = vim.api.nvim_buf_get_name(0)
    local cwd = filename ~= "" and vim.fn.fnamemodify(filename, ":p:h") or vim.fn.getcwd()

    vim.system({ "git", "-C", cwd, "rev-parse", "--show-toplevel" }, { text = true }, function(root_result)
        if root_result.code ~= 0 then
            vim.schedule(function()
                local error = (root_result.stderr or "") ~= "" and root_result.stderr or "Not inside a Git repository"
                vim.notify("Git " .. action .. " failed: " .. vim.trim(error), vim.log.levels.ERROR)
            end)
            return
        end

        local root = vim.trim(root_result.stdout)
        vim.system({ "git", action }, { cwd = root, text = true }, function(result)
            vim.schedule(function()
                if result.code ~= 0 then
                    local error = (result.stderr or "") ~= "" and result.stderr or result.stdout or ""
                    vim.notify("Git " .. action .. " failed: " .. vim.trim(error), vim.log.levels.ERROR)
                    return
                end

                vim.notify("Git " .. action .. " completed", vim.log.levels.INFO)
            end)
        end)
    end)
end

local function copy_to_clipboard(text, label)
    vim.fn.setreg("+", text)
    vim.notify("Copied " .. label .. ": " .. text, vim.log.levels.INFO)
end

local function current_file_path()
    local path = vim.api.nvim_buf_get_name(0)
    if path == "" then
        vim.notify("Current buffer has no file", vim.log.levels.WARN)
        return nil
    end
    return path
end

-- Returns git root and the file's path relative to it (forward slashes), or nil outside a repo
local function git_root_and_relative(path)
    local dir = vim.fn.fnamemodify(path, ":p:h")
    local result = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, { text = true }):wait()
    if result.code ~= 0 then
        return
    end

    -- git prints forward slashes ("C:/repo"); nvim buffer names on Windows use backslashes,
    -- so normalize both (and resolve symlinks, e.g. /tmp -> /private/tmp) before comparing
    local function norm(p)
        return vim.fs.normalize(vim.fn.resolve(p))
    end
    local root = norm(vim.trim(result.stdout))
    local full = norm(vim.fn.fnamemodify(path, ":p"))
    -- Windows paths are case-insensitive (drive letter case often differs)
    local is_windows = vim.fn.has("win32") == 1
    local cmp_root = is_windows and root:lower() or root
    local cmp_full = is_windows and full:lower() or full
    if cmp_full:sub(1, #cmp_root + 1) ~= cmp_root .. "/" then
        return
    end

    return root, full:sub(#root + 2)
end

local function copy_relative_path_from_git_root()
    local path = current_file_path()
    if not path then
        return
    end
    local _, relative = git_root_and_relative(path)
    if not relative then
        return
    end
    if vim.fn.has("win32") == 1 then
        relative = relative:gsub("/", "\\")
    end
    copy_to_clipboard(relative, "relative path")
end

local function copy_github_url()
    local path = current_file_path()
    if not path then
        return
    end
    local root, relative = git_root_and_relative(path)
    if not root then
        vim.notify("Not in a git repository", vim.log.levels.WARN)
        return
    end

    local function git(...)
        local r = vim.system({ "git", "-C", root, ... }, { text = true }):wait()
        return r.code == 0 and vim.trim(r.stdout) or nil
    end

    local remote = git("remote", "get-url", "origin")
    -- Handles git@github.com:user/repo.git, ssh://git@github.com/user/repo.git and https://github.com/user/repo.git
    local slug = remote and remote:match("github%.com[:/](.+)$")
    if not slug then
        vim.notify("No GitHub 'origin' remote found", vim.log.levels.WARN)
        return
    end
    slug = slug:gsub("/$", ""):gsub("%.git$", "")

    -- Branch name, or commit hash when HEAD is detached
    local ref = git("symbolic-ref", "--short", "-q", "HEAD") or git("rev-parse", "HEAD")
    if not ref then
        vim.notify("Could not determine git ref", vim.log.levels.WARN)
        return
    end

    local function encode(str)
        return (str:gsub("[^%w%-._~/]", function(c) return string.format("%%%02X", c:byte()) end))
    end
    local url = ("https://github.com/%s/blob/%s/%s"):format(slug, encode(ref), encode(relative))
    copy_to_clipboard(url, "GitHub URL")
end

vim.g.mapleader = " "
 
-- Save file
keymap("n", "<leader>fs", "<cmd>w<cr>")
-- Delete current file (sends to Recycle Bin / Trash), with confirmation
keymap("n", "<leader>fd", delete_file_to_trash, { desc = "Delete current file to " .. trash_name })
-- Rename current file, prompts for new filename
keymap("n", "<leader>fr", rename_file, { desc = "Rename current file" })
-- Copy current filename / full path / path relative to git root (no-op outside git)
keymap("n", "<leader>cff", function()
    local path = current_file_path()
    if path then copy_to_clipboard(vim.fn.fnamemodify(path, ":t"), "filename") end
end, { desc = "Copy current filename" })
keymap("n", "<leader>cfa", function()
    local path = current_file_path()
    if path then copy_to_clipboard(vim.fn.fnamemodify(path, ":p"), "full path") end
end, { desc = "Copy full path of current file" })
keymap("n", "<leader>cfr", copy_relative_path_from_git_root, { desc = "Copy file path relative to git root" })
keymap("n", "<leader>cfg", copy_github_url, { desc = "Copy GitHub URL of current file" })
-- Close window
keymap("n", "<leader>wq", "<cmd>q<cr>")
-- Window nav
-- https://neovim.io/doc/user/windows/
keymap("n", "<leader>wh", "<C-w>h")
keymap("n", "<leader>wj", "<C-w>j")
keymap("n", "<leader>wk", "<C-w>k")
keymap("n", "<leader>wl", "<C-w>l")
keymap("n", "<leader>w=", "<C-w>=")
keymap("n", "<leader>wv", "<cmd>vsplit<cr><C-w>=")
keymap("n", "<leader>ws", "<cmd>split<cr><C-w>=")
keymap("n", "<leader>w+", "<cmd>vertical resize +2<CR>")
keymap("n", "<leader>w-", "<cmd>vertical resize -2<CR>")
 
-- Clear search, close all other buffers and the file sidebar
keymap("n", "<leader><Esc>", function()
    vim.cmd("nohlsearch")
    pcall(vim.cmd, "Neotree close")
    close_other_buffers()
end, { desc = "Clear search highlight and close all other buffers and the file sidebar" })
 

-- Git
keymap("n", "<leader>gc", "<cmd>LazyGit<cr>", { desc = "Open LazyGit" })
keymap("n", "<leader>gf", function() run_git_action("fetch") end, { desc = "Git fetch" })
keymap("n", "<leader>gp", function() run_git_action("pull") end, { desc = "Git pull" })
keymap("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "Git file history" })
keymap("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Open Git diff" })
keymap("n", "<leader>gD", "<cmd>DiffviewClose<cr>", { desc = "Close Git diff view" })

-- Buffers
keymap("n", "<leader>bk", "<cmd>bprevious <bar> bdelete #<cr>", { noremap = true, desc = "Kill current buffer while keeping the window layout intact" })
keymap("n", "<leader>bK", close_other_buffers, { noremap = true, desc = "Kill all buffers other than the current one while keeping the window layout intact" })

-- Don't forget there's <C-^> to switch between the two last buffers
keymap("n", "<leader>bp", "<cmd>bp<cr>", { noremap = true })
keymap("n", "<leader>bn", "<cmd>bn<cr>", { noremap = true })
keymap("n", "<leader>bb", builtin.buffers, { desc = "Telescope buffers" })

-- keymap("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
keymap("n", "<leader>o", builtin.find_files, { desc = "Telescope find files" })
keymap("n", "<leader>spp", builtin.live_grep, { desc = "Telescope live grep" })
keymap("n", "<leader>spt", function()
  builtin.live_grep({ glob_pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" } })
end, { desc = "Telescope live grep (TypeScript files)" })
keymap("n", "<leader>spc", function()
  builtin.live_grep({ glob_pattern = { "*.json", "*.targets", "*.csproj", "*.vbproj", "*.proj", "*.config", "*.config.*" } })
end, { desc = "Telescope live grep (JSON/config files)" })
keymap("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })
    
keymap("n", "ge", vim.diagnostic.goto_next, { desc = "Go to next error" })
keymap("n", "gE", vim.diagnostic.goto_prev, { desc = "Go to previous error" })
keymap("n", "<leader>.", vim.diagnostic.open_float, { desc = "Line diagnostics" })

-- QuickFix list (:grep foo + :copen to open quick fix list, :cnext, :cprev)
-- :cdo lets you execute commands over all quick fix list results
keymap("n", "<leader>qq", "<cmd>copen<cr>", { desc = "Open quick fix list" })
keymap("n", "<leader>qj", "<cmd>cnext<cr>", { desc = "Go to next quick fix list result" })
keymap("n", "<leader>qk", "<cmd>cprev<cr>", { desc = "Go to previous quick fix list result" })

keymap("v", "<leader>p", '"_dP', { desc = "Paste without losing current register (Primeagen on master.dev)" })
keymap("v", "<leader>y", '"+y', { desc = "Yank into system clipboard if user doesn't have system clipboard on (Primeagen on master.dev)" })
-- gv re-highlights the previous visual selection
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move current line in visual mode down by one (Primeagen on master.dev)" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move current line in visual mode up by one (Primeagen on master.dev)" })


-- Surround
    -- keymap("i", "<C-g>s", "<Plug>(nvim-surround-insert)", { desc = "Add a surrounding pair around the cursor (insert mode)", })
    -- keymap("i", "<C-g>S", "<Plug>(nvim-surround-insert-line)", { desc = "Add a surrounding pair around the cursor, on new lines (insert mode)", })
    -- keymap("n", "ys", "<Plug>(nvim-surround-normal)", { desc = "Add a surrounding pair around a motion (normal mode)", })
    -- keymap("n", "yss", "<Plug>(nvim-surround-normal-cur)", { desc = "Add a surrounding pair around the current line (normal mode)", })
    -- keymap("n", "yS", "<Plug>(nvim-surround-normal-line)", { desc = "Add a surrounding pair around a motion, on new lines (normal mode)", })
    -- keymap("n", "ySS", "<Plug>(nvim-surround-normal-cur-line)", { desc = "Add a surrounding pair around the current line, on new lines (normal mode)", })
    -- keymap("x", "S", "<Plug>(nvim-surround-visual)", { desc = "Add a surrounding pair around a visual selection", })
    -- keymap("x", "gS", "<Plug>(nvim-surround-visual-line)", { desc = "Add a surrounding pair around a visual selection, on new lines", })
    -- keymap("n", "ds", "<Plug>(nvim-surround-delete)", { desc = "Delete a surrounding pair", })
    -- keymap("n", "cs", "<Plug>(nvim-surround-change)", { desc = "Change a surrounding pair", })
    -- keymap("n", "cS", "<Plug>(nvim-surround-change-line)", { desc = "Change a surrounding pair, putting replacements on new lines", })


-- neoroam (backlinks)
keymap("n", "<leader>nb", "<cmd>NeoroamBacklinks<cr>", { desc = "Toggle backlinks panel" })
keymap("n", "<leader>nf", "<cmd>NeoroamFollow<cr>", { desc = "Follow note link under cursor" })
keymap("n", "<leader>ni", "<cmd>NeoroamInsert<cr>", { desc = "Insert note link" })
keymap("n", "<leader>nn", "<cmd>NeoroamNew<cr>", { desc = "New note" })
