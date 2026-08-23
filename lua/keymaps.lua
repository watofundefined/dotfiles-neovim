local builtin = require("telescope.builtin")

local keymap = vim.keymap.set

vim.g.mapleader = " "
 
-- Save file
keymap("n", "<leader>fs", "<cmd>w<cr>")
-- Close window
keymap("n", "<leader>wq", "<cmd>q<cr>")
-- Window nav
-- https://neovim.io/doc/user/windows/
keymap("n", "<leader>wh", "<C-w>h")
keymap("n", "<leader>wj", "<C-w>j")
keymap("n", "<leader>wk", "<C-w>k")
keymap("n", "<leader>wl", "<C-w>l")
keymap("n", "<leader>w=", "<C-w>=")
keymap("n", "<leader>w+", "<cmd>vertical resize +2<CR>")
keymap("n", "<leader>w-", "<cmd>vertical resize -2<CR>")
 
-- Clear search
keymap("n", "<leader><Esc>", "<cmd>nohlsearch<cr>")
 
keymap("n", "<leader>ff", "<cmd>Vexplore!30<cr>", { noremap = true })
 
-- Buffers
keymap("n", "<leader>bk", "<cmd>q<cr>", { noremap = true })
-- Don't forget there's <C-^> to switch between the two last buffers
keymap("n", "<leader>bp", "<cmd>bp<cr>", { noremap = true })
keymap("n", "<leader>bn", "<cmd>bn<cr>", { noremap = true })
keymap("n", "<leader>bb", builtin.buffers, { desc = "Telescope buffers" })

 
-- WIP
-- keymap("n", "<leader>bK", "<C-w>o", { noremap = true })
-- keymap('n', '<leader>bK', '<C-w>o', { desc = 'Close other windows' })
--
--

-- keymap("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
keymap("n", "<leader>o", builtin.find_files, { desc = "Telescope find files" })
keymap("n", "<leader>sp", builtin.live_grep, { desc = "Telescope live grep" })
keymap("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })
    
keymap("n", "ge", vim.diagnostic.goto_next, { desc = "Go to next error" })
keymap("n", "gE", vim.diagnostic.goto_prev, { desc = "Go to previous error" })

-- QuickFix list (:grep foo + :copen to open quick fix list, :cnext, :cprev)
-- :cdo lets you execute commands over all quick fix list results
keymap("n", "<leader>qq", "<cmd>copen<cr>", { desc = "Open quick fix list" })
keymap("n", "<leader>qj", "<cmd>cnext<cr>", { desc = "Go to next quick fix list result" })
keymap("n", "<leader>qk", "<cmd>cprev<cr>", { desc = "Go to previous quick fix list result" })

keymap("v", "<leader>p", '"_dP', { desc = "Paste without losing current register (Primeagen on master.dev)" })
keymap("v", "<leader>y", "+y", { desc = "Yank into system clipboard if user doesn't have system clipboard on (Primeagen on master.dev)" })
-- gv re-highlights the previous visual selection
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move current line in visual mode down by one (Primeagen on master.dev)" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move current line in visual mode up by one (Primeagen on master.dev)" })


