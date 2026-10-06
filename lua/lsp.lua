-- Native (0.11+) LSP config: server definitions live in lsp/*.lua and are
-- turned on here with vim.lsp.enable().
vim.lsp.enable({ 'ts_ls' })

vim.diagnostic.config({
  virtual_text = true,
  float = { border = 'rounded', source = true },
})

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local opts = { buffer = ev.buf }
    local builtin = require('telescope.builtin')

    -- Go to definition / declaration / implementation (Telescope picker with preview)
    vim.keymap.set('n', 'gd', builtin.lsp_definitions, opts)
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gi', builtin.lsp_implementations, opts)
    -- Find usages (Telescope picker: list on the left, preview on the right)
    vim.keymap.set('n', 'gr', builtin.lsp_references, opts)
    -- Hover docs
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    -- Rename symbol
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    -- Code actions (includes ts_ls refactors like "Move to a new file")
    vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
    -- Format buffer
    vim.keymap.set('n', '<leader>cf', function() vim.lsp.buf.format({ async = true }) end, opts)
  end,
})
