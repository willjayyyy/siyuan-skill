# Export and import

32 export + 12 import endpoints (`sy api export`, `sy api import`).

## Getting markdown back out

```bash
# a single document as markdown text (returned inline)
$sy /api/export/exportMdContent -d '{"id":"<docID>"}' -q '.content'
```
`{id, addTitle?, embedMode?, refMode?, yfm?}`
- **`yfm` defaults to `true`** — YAML front-matter (`title`, `date`, `lastmod`)
  is prepended unless you pass `yfm:false`. Same for `addTitle`, which follows
  the user's export config (`true` by default), so the H1 is duplicated.
  For clean markdown: `{"id":"…","yfm":false,"addTitle":false}`.
- `refMode`: how block refs render — `2` anchor-text block link, `3` anchor text
  only, `4` footnote + anchor hash (**the default**). Values `0`, `1` and `5` are
  deprecated upstream and should not be used.
- Large documents will trip the 8 KB cap — that is correct behaviour. If you
  only need part of it, use SQL projection instead. If you genuinely need the
  whole file, write it to disk rather than into context:
  ```bash
  $sy /api/export/exportMdContent -d '{"id":"<id>"}' -r \
    | jq -r '.data.content' > /tmp/doc.md
  ```

```bash
# many documents -> a zip on the kernel's filesystem
$sy /api/export/exportMds -d '{"ids":["<id1>","<id2>"]}'
# whole notebook -> zip
$sy /api/export/exportNotebookMd -d '{"notebook":"<nbID>"}'
```
These return a **path on the kernel host**. For a remote instance that path is
not reachable from this machine — fetch it over HTTP from `$SIYUAN_URL/<path>`
instead of trying to read it locally.

## Other formats

`exportHTML` `{id, savePath, pdf, merge, keepFold}`, plus `exportDocx`,
`exportEPUB`, `exportODT`, `exportRTF`, `exportOPML`, `exportOrgMode`,
`exportAsciiDoc`, `exportMediaWiki`, `exportReStructuredText`, `exportTextile`.
All write to a path on the kernel host and return it.

`exportSY` / `exportSYs` produce SiYuan's native `.sy.zip` (lossless, keeps
block IDs) — the right choice for backup or moving content between instances.

## Import

```bash
$sy /api/import/importStdMd -d '{"localPath":"/abs/dir-or-file.md","notebook":"<nbID>","toPath":"/target/path"}'
```
Reads from the **kernel's** filesystem, not yours. For a remote instance, either
upload the content another way or just use `newdoc` with the markdown inline —
for archiving a handful of documents `newdoc` is simpler and has no path
assumptions.

`/api/import/importData` restores a full workspace export and **overwrites the
library** — it is on the CRITICAL danger list.
