# Neovim config — Roadmap

## 1. Backlinks plugin (`neoroam`)

Goal: org-roam-style backlinks while editing in Neovim.

- Lives in this repo as `lua/neoroam/` (Telescope, `vim.system`); configured by
  `vim.g.neoroam_notes_root` (optional, e.g. `"Roam"`).
- Parse `id`/`title`/`created` from frontmatter; title falls back to the filename minus
  timestamp prefix, with `_` as spaces.
- Backlinks side buffer: toggle, auto-refresh, block preview (configurable max lines,
  default 3), `<CR>` opens source at the link line.
- Follow `[text](id:uuid)` under cursor; Telescope link-insert picker; new-note command
  (title prompt, optional sub-folder choice, `YYYYMMDDHHMMSS-slug.md`).
- Parsing and ripgrep logic built test-first in pure Lua; fixtures in
  `lua/neoroam/tests/fixtures/` are the contract that TeleVim vendors.

ADR: [0001](adr/0001-roam-style-backlinks.md)
