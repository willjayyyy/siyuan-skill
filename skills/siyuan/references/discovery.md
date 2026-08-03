# Working with undocumented endpoints

The other ~440 endpoints have no reference file. This is how to use them safely
without dumping anything large into context.

## 1. Find the endpoint and its parameters

```bash
$sy api                      # list all module names
$sy api av                   # every endpoint in a module, with W/R and params
$sy api -g snapshot          # grep across all 548 routes
$sy api -w                   # every write endpoint
```

Output columns: `endpoint <TAB> methods <TAB> W|R <TAB> params`.

- `-` in the params column means **nothing was extractable — not "takes no
  parameters"**. ~20% of rows are like this; assume parameters exist and check
  the source (step 3) before concluding otherwise.
- `<multipart>` / `<websocket>` / `<sse>` / `<passthrough>` mark transports `sy`
  cannot speak; it refuses those with an explanation. For multipart see
  `asset.md`'s curl form.
- The methods column matters: a `GET`-only endpoint answers a POST with an empty
  200, which `sy` reports as "endpoint most likely does not exist".

Extracted from SiYuan **v3.7.3**. Every call is validated against this file — a
path that is not a byte-exact match is refused. So if `sy api -g` finds it you
can call it; for an endpoint added in a newer SiYuan, regenerate the TSV (recipe
at the bottom) or pass `SIYUAN_ALLOW_UNKNOWN=1` for a one-off.

## 2. Never probe an unknown endpoint blindly

**The `W`/`R` column is derived from SiYuan's `CheckReadonly` middleware, and
that is NOT the same as "read-only".** Both directions are wrong:

- Endpoints marked `R` that really do mutate state: `/api/system/exit` (kills
  the kernel process — guarded now), `/api/search/updateEmbedBlock`,
  `/api/av/changeAttrViewLayout`, `/api/av/renderAttributeView`
  (`createIfNotExist`), `/api/ref/refreshBacklink`, `/api/storage/updateRecentDoc*`,
  `/api/notebook/unlockNotebook`, `/api/repo/set*Retention*`, and the `export`
  endpoints that take a `savePath`/`folder` (they write files to disk).
- Endpoints marked `W` that are pure reads: `/api/search/searchTag`,
  `searchTemplate`, `searchWidget`, `searchAsset`, `/api/av/searchAttributeView*`,
  `/api/filetree/listDocTree`, `/api/system/getWorkspaceInfo`, and ~15 more.

So treat `W`/`R` as a weak hint, never as permission. Before the first call to
an endpoint you do not know, **read its handler source** (step 3). Reason about
what the name implies; if it could plausibly write, delete, exit, sync or export
to disk, ask the user first.

Once you know it is genuinely a read, probe narrowly:

```bash
$sy /api/xxx/yyy -d '{}' -q 'keys'        # what shape is .data?
```

An error response names the missing parameter — iterate from there. Always start
with `-q 'keys'` or `-q '.[0]'` rather than dumping the whole payload.

## 3. When params are unknown

Read the handler source. **The URL module is not the filename** — `/api/block/*`
write handlers live in `block_op.go`, `/api/query/sql`'s handler `SQL` lives in
`sql.go`, and `/api/asset/upload` is `model.Upload` in `kernel/model/`, outside
`kernel/api/` entirely. So resolve the handler symbol first, then search for it:

```bash
BASE=https://raw.githubusercontent.com/siyuan-note/siyuan/v3.7.3/kernel
# 1. endpoint -> handler symbol (last identifier on the line)
curl -s "$BASE/api/router.go" | grep '"/api/xxx/yyy"'
# 2. find that symbol — grep the whole api dir, fall back to model/
curl -s "$BASE/api/<guess>.go" | grep -A 25 'func <handler>(c \*gin.Context)'
```

If the guess 404s or the symbol isn't there, clone/download `kernel/api/*.go`
and `grep -rn "func <handler>"` across all of them.

Params appear as `arg["name"]`, `util.BindJsonArg("name", …)`, `c.Query("name")`,
`c.PostForm("name")`, or as json tags on a struct passed to `c.ShouldBindJSON`.
Some handlers delegate to a helper (`parseSearchBlockArgs(arg)`), so follow one
level of same-package calls.

## 4. Modules and what they're for

`av` attribute views (databases) · `riff` flashcards/spaced repetition ·
`repo` local snapshots & encrypted backup · `sync` cloud sync ·
`bazaar` marketplace (themes/plugins/templates) · `storage` UI state
(recent docs, search criteria) · `history` document history & rollback ·
`ai` built-in AI features · `setting` app preferences ·
`system` kernel/workspace ops · `lute` markdown engine ·
`broadcast` websocket channels · `petal`/`plugin` plugin runtime ·
`snippet` code snippets · `template` templates · `graph` graph view ·
`ref` block references · `format` document formatting · `inbox` shorthand inbox

`repo`, `sync`, `system` and `import` contain the most dangerous endpoints in the
whole API; most of them are already on the danger list.

## Regenerating the endpoint index after a SiYuan upgrade

Download **every** `kernel/api/*.go` at the new tag and verify each file is
non-empty before parsing — a silently failed download costs you a whole module's
parameters (this happened to `block.go`: 40 endpoints shipped with empty params).

From `router.go`, match `ginServer.Handle/Any/GET/POST(...)` — including routes
with `:param` / `*path` segments and non-`/api/` prefixes (`/ws/`, `/es/`,
`/plugin/`) — recording path, HTTP method(s), the handler symbol, and whether
`CheckReadonly` is in the middleware chain.

For each `func <name>(c *gin.Context)` body collect:
`arg["x"]`, `BindJsonArg("x"`, `c.PostForm("x"`, `c.Query("x"`,
`c.DefaultQuery("x"`, `MultipartForm|FormFile` → `<multipart>`, and json tags of
any struct passed to `ShouldBindJSON`/`BindJSON` (the variable may be a pointer,
so match `&?var`). Then expand **one level** of same-package helper calls of the
form `helper(arg, …)` — `fullTextSearchBlock` and the riff endpoints get their
params only this way.

Emit `endpoint<TAB>methods<TAB>W|R<TAB>params`. Handlers referenced as
`model.X` live outside `kernel/api/` and must be tagged by hand
(`/api/asset/upload` → `<multipart>`, `/api/system/getCaptcha` → `<image>`).

Sanity check the result: v3.7.3 yields 548 routes (540 under `/api/`),
300 marked `W`, and ~80% of rows with at least one parameter. A sudden drop in
that last number means a download or regex silently failed.
