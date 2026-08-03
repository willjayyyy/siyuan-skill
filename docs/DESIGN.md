# How the skill is built

Technical notes for anyone extending, auditing or debugging this skill. If you
just want to use it, the [README](../README.md) is enough.

## Layout

```
skills/siyuan/
├── SKILL.md              routing table + the rules that matter (loaded first)
├── scripts/sy            universal client — one script, all JSON endpoints
├── data/endpoints.tsv    548 routes: path, method, W/R, parameters
└── references/           nine topic files, loaded one at a time on demand
```

## Progressive disclosure

The whole point is that a large API surface should not cost a large amount of
context. Four layers, each paid for only when needed:

| Layer | Cost | Loaded when |
|---|---|---|
| Skill description | ~75 tokens | every session — unavoidable |
| `SKILL.md` | ~1.2k tokens | the user mentions SiYuan |
| One `references/*.md` | 0.6–1.8k tokens | the agent works in that area |
| `data/endpoints.tsv` (22 KB) | **0** | never read as text |

A typical "save this to my notes" request costs around **2.3k tokens**.

Two decisions carry most of that saving:

**The endpoint index is a command, not a document.** 548 routes as Markdown
would be ~4k tokens that an agent reads in full to find one line. Exposed as
`sy api -g <keyword>` it returns three lines. Any knowledge shaped like "long
list, agent needs one entry" belongs behind a filter, not in a file.

**Responses are truncated at 8 KB.** `getDoc` returns raw editor DOM — 74–108 KB
for an ordinary document, 20–30k tokens. The client cuts it off (UTF-8 safe) and
tells the agent to narrow the query instead. The equivalent projected SQL query
is around 2 KB.

## Safety design

### Guard rails

65 endpoints are refused unless `-y` is passed: 34 CRITICAL (workspace removal,
repo reset, full-library import, sync reconfiguration, account deactivation) and
31 HIGH (document/block deletion, find-and-replace, history rollback, tag
removal).

Guarding is deliberately *not* applied to rebuildable or UI-only state —
`graph/resetGraph`, `system/clearTempFiles`, `storage/*`, `bookmark/removeBookmark`.
Guarding those would train the operator to approve reflexively, which costs more
safety than it buys.

### Blast radius

Before refusing, the client reports what the call would actually affect: the
target document, its descendant block count, and how many other notes link to
it. A confirmation without numbers is not a real confirmation.

Interpolated IDs are validated against the `yyyyMMddHHmmss-xxxxxxx` pattern
first — otherwise a crafted ID turns the pre-flight query into an injection that
dumps the whole `blocks` table to stderr (where the size limit does not apply)
and shows the operator numbers belonging to someone else's rows.

If the pre-flight query itself fails, that is stated loudly. An empty blast
radius must never be mistaken for "this deletes nothing".

### Endpoint allowlist

Calls must byte-exactly match a known endpoint. This closes a parser
differential: curl collapses dot segments and the Go router percent-decodes, so
`/api/./filetree/removeDocByID` and `/api/filetree/removeDocByI%44` both reach
the real delete handler while a naive string match sees an unknown path and lets
them through. Matching against a known-good list guarantees the string the guard
checks is the string the server routes.

### Two non-obvious hazards

`/api/system/exit` is flagged `R` by the middleware but stops the kernel
process. `/api/notebook/closeNotebook` is reversible for normal notebooks, but
for the built-in user guide the kernel calls `RemoveBox()` — permanent deletion.
Both are guarded, and the second explains the branch in its blast radius report.

### Credentials

The token is passed to curl via `--config` on stdin, so it never appears in
`ps`. Request bodies go through a mode-600 temp file with a cleanup trap. The
config file is *parsed*, not sourced — sourcing would execute whatever is in it,
and a stray `exit 0` would look like a successful run. Tokens containing quotes
or newlines are rejected, since they would inject extra headers into the curl
config block.

There is no fallback URL. Defaulting to localhost would mean silently reading
and writing whatever SiYuan happens to run on the machine.

## The `W`/`R` column is a hint, not permission

It is derived from SiYuan's `CheckReadonly` middleware, which does not mean
"read-only". Both directions are wrong:

- ~17 endpoints marked `R` mutate state — `system/exit`, `search/updateEmbedBlock`,
  `av/changeAttrViewLayout`, `ref/refreshBacklink`, `storage/updateRecentDoc*`,
  `notebook/unlockNotebook`, and every `export` endpoint taking a `savePath`.
- ~20 endpoints marked `W` are pure reads — `search/searchTag`, `searchTemplate`,
  `searchWidget`, `searchAsset`, `av/searchAttributeView*`, `filetree/listDocTree`.

`references/discovery.md` tells the agent to treat the flag as weak evidence and
read the handler source before calling anything unfamiliar.

## Regenerating the endpoint index

```bash
python3 tools/gen_endpoints.py --tag v3.8.0
```

Shallow-clones the tag, parses `router.go` for every route (including `:param`
and `*path` forms and non-`/api/` prefixes), and extracts parameters from five
binding styles: `arg["x"]`, `util.BindJsonArg("x")`, `c.PostForm`, `c.Query`, and
json tags of structs passed to `ShouldBindJSON`. It also expands one level of
same-package helper calls — `fullTextSearchBlock` and the riff endpoints get
their parameters only that way.

The script **refuses to write** a file whose parameter coverage falls below 70%.
That check exists because a silent checkout failure once shipped an index where
an entire module's parameters were blank — and the documentation then grew an
explanation for it ("`-` means the endpoint takes no parameters"), which was
false. A silent data defect will grow documentation that justifies it.

v3.7.3 baseline: 548 routes, 540 under `/api/`, 300 marked `W`, ~80% with
parameters.

## Why `jq` is a dependency

SiYuan requires nothing of the client — it is an HTTP service that takes JSON and
returns JSON. `jq` follows from writing the client in bash, which cannot handle
JSON on its own.

The load-bearing use is **building** requests, not parsing responses. Note
content is arbitrary text: quotes, newlines, backslashes, tabs, CJK, emoji.
Hand-assembling that into JSON fails on the first Windows path or fenced code
block, and fails silently for a while before it fails loudly. `jq -n --arg` /
`--rawfile` gets the escaping right by construction, and reading the markdown
from a file (rather than `--arg`) also avoids `ARG_MAX` on multi-MB notes.

Zero dependencies was considered and rejected, because **no JSON tool ships on
all three platforms**: `jq` comes with recent macOS only, `python3` comes with
most Linux distributions but needs Command Line Tools on macOS, PowerShell is
Windows-only. Going dependency-free therefore means maintaining a separate JSON
backend per platform, and `-q` (a jq-specific DSL) would have no equivalent in
the fallbacks. A PowerShell backend would additionally cost 200–500 ms of
interpreter startup per call, against ~10 ms for bash + jq — noticeable when an
agent makes twenty calls in one task.

The decision: keep the single `jq` implementation, and reduce the install to one
command per platform, checked at startup with a precise error. Revisit if users
actually report the dependency as a barrier.

## Windows support

`sy` is a shell script, and Windows has no shebang mechanism — it dispatches on
file extension. `scripts/sy.ps1` is the entry point from PowerShell and CMD; it
exists because eight separate things had to be handled, each of which failed in a
way that pointed somewhere other than the cause:

| Problem | What it looked like |
|---|---|
| `bash` on PATH is `System32\bash.exe` (WSL) | a full minute of cold-start, then failure |
| MSYS2 rewrites POSIX-looking arguments | `/api/query/sql` arriving as `C:/Program Files/Git/api/query/sql` |
| `dirname` cannot parse a backslashed path | the script silently failing to locate its own directory |
| Git's Unix tools are in `<git>\usr\bin`, not on PATH, and a non-login shell skips `/etc/profile` | `dirname: command not found` — reads like a broken Git install |
| `jq` installed where a restricted shell cannot see it (winget's versioned Packages dir) | `jq` "missing" no matter how many times it was installed |
| curl is a **native** Windows binary and cannot read `/tmp/sy.XXXX` | `cannot reach <url>` — reads like the server is down |
| exit codes must survive `ps1 → bash → sy` | the guard rail's exit 3 would be invisible to the caller |
| "command not found" conflates *absent* with *not on PATH* | troubleshooting repeatedly went after the wrong one |

The last one is why `sy.ps1 --diagnose` exists: it prints the resolved bash, the
tool directories, and `command -v` for each dependency, so those two states can
be told apart.

Two scope rules were applied while fixing these. The wrapper restores only what
its own way of invoking bash took away — an earlier attempt merged the registry
PATH wholesale and was reverted, because that would silently override a PATH the
user had deliberately narrowed. And it converts only the one path curl must read,
rather than re-enabling MSYS2 conversion globally, which would break endpoints
again.

Verified end to end on Windows via Codex CLI in a restricted sandbox: SQL reads,
guard-rail refusal with exit 3 propagated back to PowerShell, and blast-radius ID
validation all behave as on macOS.

## Known limitations

**Not callable through the client**, all tagged in the index so the client can
explain why: multipart uploads (13), WebSocket and SSE routes (~8), GET-only
endpoints that answer POST with an empty 200, and handlers returning raw bytes
rather than the standard envelope.

**Export endpoints return a path on the kernel host**, not the file. Fetch it
over HTTP from `$SIYUAN_URL/<path>` — those routes are outside `/api/` and the
client does not touch them.

**The SQLite index rebuilds asynchronously.** A `SELECT` immediately after a
write or delete can return stale rows. Chain writes off the ID the API returned
rather than re-querying.

**SQL cannot express document order.** `sort` is a static block-type rank, not a
position — every heading in a document has `sort=5`. Use
`/api/block/getChildBlocks` or `/api/outline/getDocOutline` when order matters.

## Compatibility

Developed and verified against SiYuan **v3.7.3** on macOS (bash 3.2, BSD
userland) against a live instance. The kernel API is stable across patch
releases; regenerate the index after a minor upgrade.

Dependencies: `bash`, `curl`, `jq`; `iconv` is optional. `curl` and `jq` are
checked at startup — a missing `jq` used to surface as `payload is not valid
JSON: {}`, because `jq . 2>/dev/null` swallows "command not found" and only its
exit status survives. `iconv` degrades gracefully: without it, a truncated
response may end mid-character.

No Python or Node runtime is involved; `tools/gen_endpoints.py` is a maintainer
script, not a runtime dependency.
