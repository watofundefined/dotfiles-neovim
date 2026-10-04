-- See also:
-- - https://lazy.folke.io/spec/examples
-- - nvim/lua/config/lazy.lua
require("lazy").setup({
  {
      'nvim-telescope/telescope.nvim',
      version = '*',
      dependencies = {
          'nvim-lua/plenary.nvim',
          -- optional but recommended
          { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
      },
      config = function()
        -- Cache the git root so we don't shell out on every displayed row.
        -- Refreshed whenever the working directory changes.
        local git_root
        local function refresh_git_root()
          local result = vim.fn.systemlist('git rev-parse --show-toplevel')
          git_root = (vim.v.shell_error == 0 and result[1] ~= '') and result[1] or nil
        end
        refresh_git_root()
        vim.api.nvim_create_autocmd('DirChanged', { callback = refresh_git_root })

        -- Windows LSP servers can report paths with a different drive-letter
        -- case than `cwd`/git root, which breaks Telescope's usual relative
        -- path detection and makes it fall back to full absolute paths.
        -- Do the relativization ourselves, case-insensitively.
        local function make_relative(base, full)
          if not base then return nil end
          local norm_base = base:gsub('\\', '/'):lower()
          local norm_full = full:gsub('\\', '/')
          if norm_full:lower():sub(1, #norm_base) == norm_base then
            local rel = norm_full:sub(#norm_base + 1):gsub('^/+', '')
            return rel ~= '' and rel or vim.fn.fnamemodify(full, ':t')
          end
          return nil
        end

        local function relative_path_display(_, path)
          return make_relative(vim.loop.cwd(), path)
              or make_relative(git_root, path)
              or path
        end

        require('telescope').setup({
          defaults = {
            -- Wait for a pause in typing before filtering/searching, instead of
            -- re-running the search on every keystroke.
            debounce = 250,
            -- Show paths relative to cwd (falling back to the git root)
            -- instead of Windows' absolute paths.
            path_display = relative_path_display,
          },
        })
        pcall(require('telescope').load_extension, 'fzf')
      end,
  },

  {
    "MagicDuck/grug-far.nvim",
    config = function()
      require("grug-far").setup({})
    end,
    keys = {
      {
        "<leader>sr",
        function()
          require("grug-far").open({
            prefills = { paths = vim.fn.getcwd() },
          })
        end,
        desc = "Search and replace",
      },
    },
  },

  {
    "kdheepak/lazygit.nvim",
    cmd = {
      "LazyGit",
      "LazyGitConfig",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
    keys = {
      { "<leader>ga", "<cmd>Gitsigns blame<cr>", desc = "Git blame current file" },
      { "<leader>gj", "<cmd>Gitsigns nav_hunk next<cr>", desc = "Next Git hunk" },
      { "<leader>gk", "<cmd>Gitsigns nav_hunk prev<cr>", desc = "Previous Git hunk" },
    },
  },

  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    opts = {
      picker = "telescope",
      enable_builtin = true,
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
  },

  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').install { 'markdown', 'markdown_inline', 'bash', 'javascript', 'typescript', 'tsx' }

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "markdown", "sh", "bash", "javascript", "typescript", "typescriptreact" },
        callback = function()
          vim.treesitter.start()
        end,
      })
    end,
  },

  {
    "kylechui/nvim-surround",
    version = "^4.0.0", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    -- Optional: See `:h nvim-surround.configuration` and `:h nvim-surround.setup` for details
    -- config = function()
    --     require("nvim-surround").setup({
    --         -- Put your configuration here
    --     })
    -- end
  },
 
})
