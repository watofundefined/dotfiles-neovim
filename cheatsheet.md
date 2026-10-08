# Neovim cheatsheet

Leader is `<Space>`. This file collects what is worth remembering about this config.

## File sidebar (`neo-tree`)

| Key              | What it does                                                           |
|------------------|------------------------------------------------------------------------|
| `<leader>ff`     | Open the sidebar if needed, reveal the current file and focus it       |
| `<leader>ts`     | Toggle the sidebar                                                     |
| `<leader><Esc>`  | Clear search highlight, close the sidebar and all other buffers        |

Inside the tree, `<Esc>` returns focus to the previous window (or the first regular one).

Press `?` inside the tree for its own mappings (add, delete, rename, copy, move...).

## Copy file paths

| Key             | What it does                                                    |
|-----------------|-----------------------------------------------------------------|
| `<leader>cff`   | Copy the current filename                                       |
| `<leader>cfa`   | Copy the full path of the current file                          |
| `<leader>cfr`   | Copy the path relative to the git root (no-op outside a repo)   |

## Notes plugin (`neoroam`)

Org-roam-style backlinks for Markdown notes. Design: [ADR-0001](docs/adr/0001-roam-style-backlinks.md).

A note is a Markdown file with an `id` in its frontmatter; notes link to each other with
`[text](id:<uuid>)`. Links survive renames and moves because they resolve by id.

```
---
id: 620b6220-a3b9-44b4-970e-b6d221fa1dca
title: Kirby CMS
created: 2024-12-08T17:11:05
---
```

### Keys and commands

| Key          | Command             | What it does                                         |
|--------------|---------------------|------------------------------------------------------|
| `<leader>nn` | `:NeoroamNew`       | Create a note (folder first, then title)             |
| `<leader>ni` | `:NeoroamInsert`    | Fuzzy-pick a note and insert a link to it at cursor  |
| `<leader>nf` | `:NeoroamFollow`    | Open the note linked under the cursor                |
| `<leader>nb` | `:NeoroamBacklinks` | Toggle the backlinks panel                           |

### Creating a note (`<leader>nn`)

1. If the notes root has sub-folders, choose one (or `(top level)`). A flat layout skips this.
2. Type the title. The file becomes `<folder>/YYYYMMDDHHMMSS-<slug>.md` with `id`, `title`
   and `created` filled in, and you land in insert mode below the frontmatter.

Cancel at any point: `<Esc>` or `<C-c>` in either prompt, or submit an empty title.
Nothing is created and an existing file is never overwritten.

### Inserting a link (`<leader>ni`)

Type to filter by title or path; `<CR>` inserts `[title](id:uuid)` after the cursor.
Notes without an `id` get one added first (the file is saved if its buffer had no unsaved
changes). `<Esc>` closes the picker.

### Following a link (`<leader>nf`)

Put the cursor anywhere on the link (a line may contain several) and press the key.
A duplicate id is reported, not guessed.

### Backlinks panel (`<leader>nb`)

Opens on the right and follows the note you are editing (refreshes when you switch buffers
or save). Notes that link to the current one are grouped by source, each with a short block
preview; links to the current note are bold and underlined.

In the panel: `<CR>` open the source at the link line, `r` refresh, `q` close.
Unsaved changes show up after the write.

### Options

```lua
vim.g.neoroam_notes_root = "Roam"        -- restrict to <git root>/Roam (default: whole repo)
require("neoroam").setup({
  preview_lines = 3,    -- max lines per backlink preview
  panel_width = 60,
  debounce_ms = 150,
})
```

Colors: `NeoroamHeading`, `NeoroamPath`, `NeoroamLink`, `NeoroamCurrentLink`.

### Tests

```
nvim --headless -u NONE -l lua/neoroam/tests/run.lua
```
