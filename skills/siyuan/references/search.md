# Search

16 endpoints (`sy api search`). For most agent work **SQL `LIKE` is better** —
it lets you project columns and control the row count. Use these when you need
SiYuan's ranking, snippets, or its query syntax.

## Full-text

```bash
$sy /api/search/fullTextSearchBlock -d @q.json -q '[.blocks[]|{id,hPath,content}]'
```
`{query, method, types, subTypes, paths, notebook, groupBy, orderBy, page, pageSize}`

- `method`: `0` keyword (default), `1` query syntax, `2` SQL, `3` regex
- `types`: object of booleans, e.g.
  `{"document":true,"heading":true,"paragraph":true,"codeBlock":false}` —
  omit to search everything
- **`paths` takes internal IDs, not hpaths, and invalid entries are silently
  ignored** (producing an unscoped search, not an error). To scope to a
  notebook: `"paths":["<boxID>"]`. To scope to a subtree:
  `"paths":["<boxID>/<internal .sy path prefix>"]`. Passing
  `["<boxID>/Getting Started"]` looks reasonable and silently searches everything.
- **`notebook` does NOT scope the search** — it is only used for encrypted-box
  routing. Use `paths` instead.
- `orderBy`: `0` **block type (default, not relevance)**, `1` created asc,
  `2` created desc, `3` updated asc, `4` updated desc, `5` content order
  (only when grouping by doc), `6` relevance asc, `7` relevance desc.
  For "best match first" you want **`7`**, not `0`.
- **Always set `pageSize`** (e.g. 20) and always project with `-q`. The default
  response embeds full block content for every hit and will hit the 8 KB cap.

`semanticSearchBlock` (3.7+) does vector search over `block_embeddings`; it only
returns results if the user has enabled and built embeddings.

## Tags, refs, templates, assets

```bash
$sy /api/search/searchTag -d '{"k":"architecture"}'          # tag autocomplete
$sy /api/search/searchRefBlock -d '{"k":"keyword","rootID":"<docID>"}'
$sy /api/search/searchAsset -d '{"k":"diagram","exts":[".png"]}'
$sy /api/search/fullTextSearchAssetContent -d '{"query":"..."}'   # inside PDFs etc.
$sy /api/search/searchTemplate -d '{"k":"daily-report"}'     # templates under data/templates/
$sy /api/search/searchWidget -d '{"k":"..."}'
```

Despite the `W` flag in `sy api`, `searchTag` / `searchTemplate` / `searchWidget`
/ `searchAsset` are **pure reads** — the flag comes from SiYuan's middleware, not
from behaviour (see `discovery.md`).

`/api/search/removeTemplate` deletes a template file and is guard-railed.

Tag inventory is cheaper via SQL:
`SELECT DISTINCT tag FROM blocks WHERE tag != ''`

## findReplace — guarded

```bash
$sy /api/search/findReplace -d '{"k":"old","r":"new","ids":["<docID>"]}' -y
```
`{k, r, ids, replaceTypes, method, types, paths, notebook}`

Refused without `-y`. It rewrites matched blocks in place across the given
scope with **no per-block undo**. Always scope it with `ids` or `paths`; a
library-wide replace is almost never what the user meant. Preview the impact
first with the equivalent SQL `LIKE` count.
