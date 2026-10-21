# neoroam

Roam-style linked notes in Markdown: every note has a stable id, notes link to each other by id, and a side panel lists what links to the current note.

## Language

**Note**:
A Markdown file inside the notes root, identified by the `id` in its frontmatter.
_Avoid_: Page, document

**Id**:
The lowercase UUID v4 in a note's frontmatter that identifies it across renames and moves.
_Avoid_: Key, slug

**Link**:
A reference from one note to another, written `[text](id:<uuid>)`. The text is cosmetic; the id is the truth.
_Avoid_: Wikilink, reference

**Backlink**:
A link to the current note found in a different note. A note linking to itself is not a backlink.
_Avoid_: Incoming link, mention

**Repo root**:
The git root of the current buffer's repository, or the working directory when there is none.

**Notes root**:
The folder that scopes all searches and commands: the repo root plus `neoroam_notes_root` when set, otherwise the repo root itself.
_Avoid_: Vault, root (unqualified)

**Duplicate id**:
Two or more notes sharing one id. Reported with a warning, and following a link to it lets you choose among them.

**Preview**:
The block of text around a backlink's line, capped at a configurable number of lines.
