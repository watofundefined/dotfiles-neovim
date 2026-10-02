# ADR-0001: Roam-style backlinks via `id:` links and ripgrep, no index

## Status

Accepted

## Context

Notes were migrated from Emacs org-roam to Markdown. The owner wants org-roam's core
workflow back: every note has a stable id, notes link to each other by id, and while
editing a note a side buffer lists every note that links to it, with a preview.
org-roam keeps a SQLite database for this because it parses org files in Elisp, which is
slow. The notes are also served by the TeleVim project, whose lite view will want the same
feature (see TeleVim ADR-0011, which depends on this one).

TeleVim's server is Node and does not talk to the Neovim it hosts (Neovim runs in a tmux
session behind a PTY). It already checks out this config repo at container start
(TeleVim ADR-0009). So TeleVim cannot call this plugin, but it does receive it for free.
What the two must share is a format contract, not code.

## Decision

**Note format.** A note's identity is an `id` in YAML frontmatter:

```
---
id: 620b6220-a3b9-44b4-970e-b6d221fa1dca
title: Kirby CMS
created: 2024-12-08T17:11:05
---
```

- Links are exactly `[text](id:<uuid>)`. No wikilinks, no heading anchors.
- Ids are lowercase UUID v4. Searches are case-insensitive.
- Title is the frontmatter `title:` field. Fallback: the filename without `.md`, with a
  leading `^\d{14}-` timestamp stripped and `_` replaced by spaces
  (`20241208171105-kirby_cms.md` -> `kirby cms`).
- `created` is local time, `YYYY-MM-DDTHH:MM:SS`. Written on note creation only.
- Parsers read `id`, `title` (and tolerate `created`) line by line, ignore unknown fields,
  and tolerate quoted values, a BOM and CRLF. No YAML library.
- Frontmatter means the `---` fenced block at the very start of the file.
- Links resolve by id, never by path, so renaming or moving a file never breaks them.

**Scope.**

- `<root>` is the git root of the current buffer's repository, falling back to cwd.
- `vim.g.neoroam_notes_root` (optional, relative to `<root>`, e.g. `"Roam"`) restricts
  everything to `<root>/<notes_root>/`, recursively. Unset means the whole `<root>`.
  Sub-folders (`Roam/People`, ...) and a flat layout both work with no other configuration.
- The backlinks panel and link commands only activate for markdown buffers inside that scope.

**No index.** Everything is computed on demand with ripgrep (same reasoning as TeleVim
ADR-0008). Flags: `-g '*.md' --no-messages --no-require-git`; `.gitignore` is honoured,
hidden files are skipped (ripgrep defaults). Output is parsed from `--json`, never from
`file:line:text` (paths may contain colons).

- Backlinks of the current note: its id is read from the buffer's own frontmatter (no
  search). Then `rg -F -i "](id:<id>)"`. Each hit yields source file, line, and a preview.
- Id -> file (used when following a link): `rg -m1 -i "^id:\s*['\"]?<id>['\"]?\s*$"` collects at
  most one hit per file; each hit is verified to lie inside that file's frontmatter, and a
  body-only match is discarded (it does not count as a duplicate). All matching files are
  returned. More than one is a duplicate and is reported, never
  resolved silently.
- Title of a backlink's source: read that file's frontmatter (first lines only).
- Links inside code fences or code spans are not excluded; this is accepted.
- Unsaved buffers are not on disk, so their changes appear in backlinks after the write.

**Preview.** The block around the link line, capped at N lines (default 3), where N is a
plugin option. A block ends at a blank line, a heading, a code fence, or the start of a
list item at the same or shallower indent than the item containing the link. A link in a
bullet therefore previews that bullet and its indented continuation, not the whole list.
If the block exceeds N lines, show the N-line window that contains the link line.

**Neovim plugin.** `neoroam`, in this repo under `lua/neoroam/` (on the runtimepath, no
separate repo). Neovim 0.10+ (`vim.system` for async ripgrep); Telescope is required
lazily and only by the picker. It provides:

- a toggleable backlinks side buffer for the current note: scratch buffer in a vertical
  split, auto-refreshing on `BufEnter` and `BufWritePost`, debounced with one timer;
  in-flight requests are killed or discarded when a newer one starts; the panel buffer
  itself and non-note buffers never trigger a refresh; grouped by source note;
  `<CR>` opens the source at the link line in the previous window,
- following the `id:` link under the cursor (the link whose span contains the cursor
  column; a line may hold several),
- a Telescope picker that inserts `[title](id:<uuid>)` (title with `[`/`]` escaped) at the
  cursor. It lists every `*.md` in scope, including notes without an id, and adds an `id`
  to the target if it lacks one (creating frontmatter if absent; editing the buffer if it
  is loaded, otherwise the file),
- new-note creation: prompt for a title; if the notes root has first-level sub-folders,
  `vim.ui.select` among them plus "(top level)" (sub-folders are scanned live, so a flat
  layout skips the question); create `<folder>/YYYYMMDDHHMMSS-<slug>.md` with `id`,
  `title`, `created`. Slug: lowercase, spaces to `_`, other non-alphanumerics dropped,
  Latin diacritics mapped to ASCII; an empty slug becomes `untitled`. An existing file is never overwritten. UUIDs come
  from `vim.uv.random` (no `uuidgen` dependency).

**Contract and tests.** Parsing and preview logic is pure Lua (no `vim.api`), built
test-first and runnable headless. Language-neutral fixtures (`.md` files plus expected
JSON) live in this repo under `lua/neoroam/tests/fixtures/` and are the canonical contract.
TeleVim vendors a copy into its own tests with a sync script (it is the consumer; this
repo stays TeleVim-agnostic, per TeleVim ADR-0009).

**Out of scope.** Tags are a separate plugin and a separate decision. Also deferred:
aliases, daily notes, unlinked mentions, forward-link panel, graph view.

## Consequences

- No database, schema, or reindexing; the files are the only source of truth.
- Cost is one ripgrep process per lookup: milliseconds at hundreds to low-thousands of
  notes. Revisit if the corpus grows by an order of magnitude or a graph view is wanted;
  an index can be rebuilt from the files, so deferring it loses nothing.
- Duplicate ids make id -> file ambiguous; the plugin reports them.
- TeleVim reimplements the same rules in Node and is checked against the same fixtures, so
  a change to the format means changing the fixtures first, then both implementations.
- The title fallback and the `created` field are part of the shared contract.
- Requires `ripgrep` on PATH (already in the TeleVim image).
