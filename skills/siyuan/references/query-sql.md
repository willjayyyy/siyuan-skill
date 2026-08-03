# SQL — reading the note index

This is a **regular REST endpoint** — `POST /api/query/sql`, same auth, same
`{code,msg,data}` envelope as every other call. It is not a direct database
connection; the kernel owns the SQLite file.

`sy sql "..."` sends `{"stmt":"...","mode":"readonly"}`. The `mode` field
matters:

| mode | behaviour |
|---|---|
| `readonly` | non-SELECT is rejected with `SQL statement is not a read-only query` — **what `sy sql` uses** |
| `` (default) | single statement only; non-SELECT returns `code:0, data:null` and silently does nothing |
| `multiple` | no validation at all |

Always prefer `readonly`: the server enforces the intent and a mistake surfaces
as an error instead of a silent `null` you might read as success.

Results cap at 64 rows by default. Add `LIMIT`/`OFFSET` explicitly for more.

## When to use SQL vs the wrapped endpoints

SiYuan has plenty of purpose-built read endpoints — `getDocOutline`,
`getChildBlocks`, `getBlockKramdown`, `listDocsByPath`, `fullTextSearchBlock`,
`exportMdContent`. They work, and for one-off structural reads they are fine.

SQL wins for **reading content** for one reason: those endpoints have no field
projection — they return their full shape, padded with editor metadata you did
not ask for. Measured on a real doc:

| call | bytes (two real docs) |
|---|---|
| `/api/outline/getDocOutline` | 8 610 / 16 921 — carries `box`, `hPath`, `nodeType`, `depth`, `folded`, `updated`, and HTML entities (`&nbsp;`, `<span data-type="code">`) inside `name` |
| equivalent SQL | 2 322 / 2 606 — plain text, no markup |
| `/api/filetree/getDoc` | 74 221 / 108 648 — full editor DOM |

(Ratios hold across documents; the absolute numbers scale with document size.
Note the outline endpoint is under `/api/outline/`, not `/api/filetree/`.)

So: **writes and structural operations go through the wrapped endpoints**
(`createDocWithMd`, `appendBlock`, `renameDocByID`, …). Reading content goes
through SQL. Use `getDocOutline` when you need block IDs plus fold state in one
shot; use SQL when you need the text.

## Tables

```
blocks    id parent_id root_id hash box path hpath name alias memo tag
          content fcontent markdown length type subtype ial sort created updated
refs      id def_block_id def_block_parent_id def_block_root_id def_block_path
          block_id root_id box path content markdown type
attributes id name value type block_id root_id box path
assets    id block_id root_id box docpath path name title hash
spans     id block_id root_id box path content markdown type ial
blocks_fts  -- FTS5 mirror of blocks, used by the search API
block_embeddings -- vectors for semanticSearchBlock (3.7+)
```

Column notes:
- `box` = notebook ID. `root_id` = the containing document's ID. For a document
  block itself, `id == root_id`.
- `content` is plain text; `markdown` keeps the markup; `fcontent` is the first
  child's text (used for list items). Prefer `content` for reading, `markdown`
  when you need to round-trip.
- `hpath` = human path `/Notes/2026-08-03-title`. `path` = internal
  `/2026...-xxx.sy`. Filter on `hpath`, never on `path`.
- `ial` holds the block's inline attribute string, e.g.
  `{: id="..." name="..." custom-source="claude"}`.
- `created`/`updated` are `yyyyMMddHHmmss` **strings**, not epochs. Compare
  lexically: `WHERE updated > '20260801000000'`.
- IDs embed their creation time, so `ORDER BY id DESC` == newest first.

## Block types (`type` / `subtype`, verified against a live library)

| type | meaning | subtype |
|---|---|---|
| `d` | document | — |
| `h` | heading | `h1`…`h6` |
| `p` | paragraph | — |
| `l` | list | `u` unordered, `o` ordered, `t` task |
| `i` | list item | same as parent list |
| `c` | code block | — |
| `t` | table | — |
| `b` | blockquote | — |
| `s` | super block | — |
| `m` | math block | — |
| `tb` | thematic break | — |
| `av` | attribute view (database) | — |
| `callout` | callout | `NOTE` `TIP` `IMPORTANT` `WARNING` `CAUTION` |
| `html` `iframe` `video` `audio` `widget` `query_embed` | embeds | — |

A document's text lives in its child blocks, not in the `d` row.

## Recipes

```sql
-- all notebooks with doc counts
SELECT box, count(*) c FROM blocks WHERE type='d' GROUP BY box

-- find a document by title
SELECT id, hpath FROM blocks WHERE type='d' AND content LIKE '%keyword%'

-- outline of a document (cheap alternative to getDoc) — SEE THE ORDERING TRAP BELOW
SELECT id, subtype, content FROM blocks
WHERE root_id='<docID>' AND type='h'

-- full text of a document, projected
SELECT type, content FROM blocks
WHERE root_id='<docID>' AND type IN ('h','p','c')

-- keyword search across the library, newest first
SELECT root_id, hpath, substr(content,1,80) preview FROM blocks
WHERE content LIKE '%keyword%' AND type IN ('p','h') ORDER BY id DESC LIMIT 20

-- docs touched in the last 7 days (compare as strings)
SELECT hpath, updated FROM blocks
WHERE type='d' AND updated > '20260727000000' ORDER BY updated DESC

-- blocks carrying a tag
SELECT root_id, hpath, content FROM blocks WHERE tag LIKE '%#architecture#%'

-- what links to this document
SELECT DISTINCT root_id, content FROM refs WHERE def_block_root_id='<docID>'

-- blocks written by this skill (see attr-tag.md for the convention)
SELECT b.hpath, b.content FROM blocks b JOIN attributes a ON a.block_id=b.id
WHERE a.name='custom-source' AND a.value='claude'

-- duplicate-title check before archiving
SELECT id, hpath FROM blocks WHERE type='d' AND content='2026-08-03-title'
```

## Traps

- **SQL cannot give you document order. There is no column for it.**
  `sort` is a static *block-type* rank, not a position — document=0, heading=5,
  paragraph/code/math/table=10, list/listitem/blockquote/callout=20,
  superblock/av=30. Every heading in a document has `sort=5`, so `ORDER BY sort`
  groups by type and scrambles the reading order. `ORDER BY id` fails too: blocks
  created in the same second share a timestamp prefix. Observed output:
  ```
  h/5 Overview | h/5 Usage | h/5 Auto-backup | p/10 <para text> | p/10 <para text>
  ```
  all headings first, then all paragraphs — not the document.
  **For real order use `/api/block/getChildBlocks` (document order, one level) or
  `/api/outline/getDocOutline` (headings, nested).** Use SQL when you need
  filtering, counting or projection; use those two when order matters.
- **The index rebuilds asynchronously.** A SELECT immediately after a write or
  delete can still show the old state. Re-query before concluding anything.
- `LIKE` is case-sensitive for CJK but not ASCII; SQLite has no regex here.
- Escaping: build the statement with `jq -n --arg` (which `sy sql` already does)
  rather than string-concatenating quotes in shell.
- Encrypted notebooks that are locked are **absent from the index** entirely —
  zero rows is not proof the content doesn't exist. See `notebook.md`.
