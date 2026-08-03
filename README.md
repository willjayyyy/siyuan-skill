<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

# SiYuan Agent Skill

**Give your coding agent full, guard-railed access to your [SiYuan](https://github.com/siyuan-note/siyuan) knowledge base.**

English · [简体中文](README.zh-CN.md)

</div>

---

An [Agent Skill](https://docs.claude.com/en/docs/claude-code/skills) that lets Claude Code (and
any agent that can read a `SKILL.md` and run a shell script) read from and write to a
self-hosted SiYuan instance over its kernel HTTP API — **all 540 JSON endpoints**, not a
hand-picked subset.

```bash
# archive a note
$ sy newdoc <notebookID> "/Notes/2026-08-03-title" note.md
"20260803172432-62qup5b"

# query the library cheaply
$ sy sql "SELECT hpath FROM blocks WHERE type='d' AND content LIKE '%kubernetes%'"
[{"hpath":"/Ops/k8s-troubleshooting"}]

# destructive calls are refused until a human confirms
$ sy /api/filetree/removeDocByID -d '{"id":"20260803172432-62qup5b"}'
REFUSED: /api/filetree/removeDocByID is HIGH — irreversible.
── blast radius ──
[{"hpath":"/Notes/2026-08-03-title","type":"d"}]
[{"descendant_blocks":9}]
[{"inbound_refs":0}]
── Ask the user to confirm, then re-run with -y ──
```

## Why a Skill instead of an MCP server

SiYuan's kernel exposes **540 JSON endpoints**. An MCP server has to declare a tool schema for
each one up front, and SiYuan publishes no OpenAPI spec — which is why every community MCP
server for SiYuan wraps only a dozen or two.

A Skill inverts this. It ships one universal client plus a **queryable** endpoint index, so
coverage is complete by construction, and the knowledge loads progressively:

| Layer | Cost | Loaded when |
|---|---|---|
| Skill description | ~75 tokens | every session (unavoidable) |
| `SKILL.md` | ~1.2k tokens | you mention SiYuan |
| One `references/*.md` | 0.6–1.8k tokens | the agent works on that area |
| 548-route index (22 KB) | **0** | never read as text — only grepped via `sy api` |

A typical archive-a-note task costs about **2.3k tokens**, not the 20k+ it would take to hold
an API surface this size in context.

## Features

- **Complete coverage.** Any of the 540 JSON endpoints is callable; the index also records the
  ~8 WebSocket/SSE routes so the client can explain why it *can't* call them.
- **Guard rails on destructive calls.** 34 CRITICAL + 31 HIGH endpoints are refused unless `-y`
  is passed, and the client first prints a **blast radius** (affected documents, descendant
  block count, inbound references) so the human confirms with real numbers.
- **Endpoint allowlist.** Calls must byte-exactly match a known endpoint. This closes a
  parser-differential hole: `/api/./filetree/removeDocByID` and `/api/filetree/removeDocByI%44`
  are normalised by curl and the Go router into a real delete handler, while a naive string
  match sees an unknown path.
- **Read-only SQL by default.** `sy sql` pins `mode=readonly` so the server rejects non-SELECT
  statements loudly, instead of the default mode's silent `code:0, data:null`.
- **Response truncation.** Oversized replies are cut at 8 KB (UTF-8 safe) with guidance to
  narrow the query. `getDoc` on a normal document returns 74–108 KB of editor DOM; the
  equivalent projected SQL is ~2 KB.
- **Credentials never on the command line.** The token goes to curl via `--config` on stdin, so
  it is not visible in `ps`; request bodies go through a mode-600 temp file with a cleanup trap.
- **No silent fallbacks.** Missing configuration is an error, never a guess at `localhost` —
  guessing would mean reading and writing the wrong library.
- **Reproducible index.** `tools/gen_endpoints.py` regenerates the endpoint index from any
  SiYuan tag and refuses to emit a file whose parameter coverage collapsed.

## Requirements

- A running SiYuan instance (developed against **v3.7.3**) with its API reachable over HTTP
- `bash`, `curl`, `jq`, `iconv` — all present by default on macOS and most Linux distributions
- An API token from SiYuan: **Settings → About → API token**

## Install

### Option A — let your agent do it (recommended)

Paste this to Claude Code:

> Install the SiYuan skill from https://github.com/willjayyyy/siyuan-skill by following its
> `docs/AGENT-INSTALL.md`, then configure it for my instance and verify the connection.

The agent will clone the repo, install the skill, ask you for your SiYuan URL and API token,
write `~/.config/siyuan/env` with mode 600, and verify by listing your notebooks. Full
instructions live in [`docs/AGENT-INSTALL.md`](docs/AGENT-INSTALL.md).

### Option B — Claude Code plugin

```
/plugin marketplace add willjayyyy/siyuan-skill
/plugin install siyuan@siyuan-skill
```

Then configure credentials (see [Configuration](#configuration)).

### Option C — manual

```bash
git clone https://github.com/willjayyyy/siyuan-skill.git
cp -R siyuan-skill/skills/siyuan ~/.claude/skills/siyuan
chmod +x ~/.claude/skills/siyuan/scripts/sy
```

For other agents, point them at `skills/siyuan/SKILL.md` and put `scripts/sy` on the `PATH`.

## Configuration

Credentials live **outside** the skill directory so the skill stays shareable.

### Let the agent do it

> Configure the SiYuan skill for my instance at `http://192.168.1.10:6806`, my token is in my
> password manager — ask me for it, write the config with the right permissions and verify it
> works.

### Manually

The config path is resolved per platform, in this order:

1. `$SIYUAN_CONF` — explicit override
2. `$XDG_CONFIG_HOME/siyuan/env` — when `XDG_CONFIG_HOME` is set
3. `$APPDATA/siyuan/env` — Windows (Git Bash / MSYS2 / Cygwin)
4. `$HOME/.config/siyuan/env` — macOS and Linux default

**macOS / Linux**

```bash
mkdir -p ~/.config/siyuan
umask 077
cat > ~/.config/siyuan/env <<'EOF'
SIYUAN_URL=http://<host>:6806
SIYUAN_TOKEN=<your API token>
EOF
chmod 600 ~/.config/siyuan/env
```

**Windows (Git Bash)**

```bash
mkdir -p "$APPDATA/siyuan"
cat > "$APPDATA/siyuan/env" <<'EOF'
SIYUAN_URL=http://<host>:6806
SIYUAN_TOKEN=<your API token>
EOF
```

Verify:

```bash
~/.claude/skills/siyuan/scripts/sy nb
# 20210808180117-czj9bvb   User Guide
# 20260101120000-abcdefg   My Notebook
```

| Variable | Required | Meaning |
|---|---|---|
| `SIYUAN_URL` | yes | e.g. `http://192.168.1.10:6806`, no trailing slash |
| `SIYUAN_TOKEN` | yes | Settings → About → API token |
| `SIYUAN_CONF` | no | explicit config path, overriding the resolution order above |
| `SIYUAN_MAX_BYTES` | no | response truncation limit, default `8192` |
| `SIYUAN_TIMEOUT` | no | curl timeout in seconds, default `30` |
| `SIYUAN_ALLOW_UNKNOWN` | no | allow endpoints absent from the index (after a SiYuan upgrade) |

Environment variables override the config file, so a second instance needs no edits:

```bash
SIYUAN_URL=http://other:6806 SIYUAN_TOKEN=... sy nb
```

> **Security note.** The token grants full read/write access to the whole library. Keep the
> config file at mode 600, and if you expose SiYuan beyond your LAN, put it behind a reverse
> proxy with its own authentication.

## Usage

Once installed, just talk to your agent: *"archive this troubleshooting write-up into SiYuan"*,
*"what do my notes say about the k8s upgrade?"*. The skill loads on its own.

The client is also useful directly:

```bash
sy nb                                   # list notebooks
sy sql "SELECT ..."                     # query the index (read-only)
sy newdoc <nbID> <hpath> <md-file|->    # create a document from markdown
sy append <parentID> <md-file|->        # append markdown to a container block
sy <endpoint> -d '<json>' [-q '<jq>']   # call any of the 540 JSON endpoints
sy api <module> | -g <pattern> | -w     # discover endpoints and their parameters
```

Flags: `-d @file` / `-d @-` read the body from a file or stdin; `-q` applies a jq filter to
`.data`; `-r` prints the full envelope untruncated; `-y` confirms a destructive call;
`--max N` raises the truncation limit.

Exit codes: `0` success · `1` error · `3` refused (destructive, needs `-y`).

## What the agent reads

```
skills/siyuan/
├── SKILL.md                 routing table + the rules that matter (always loaded first)
├── scripts/sy               the universal client
├── data/endpoints.tsv       548 routes: path, methods, W/R, parameters (grepped, never read)
└── references/
    ├── query-sql.md         table schemas, block types, recipes, ordering traps
    ├── doc-crud.md          documents: create, move, rename, delete
    ├── block-crud.md        blocks: insert, update, delete, daily notes
    ├── search.md            full-text search, tags, refs, find & replace
    ├── attr-tag.md          block attributes, tags, bookmarks
    ├── asset.md             image and attachment upload
    ├── export-import.md     export to md/html/docx, import
    ├── notebook.md          notebooks, including encrypted and locked ones
    └── discovery.md         how to use the ~450 endpoints with no reference file
```

## Regenerating the endpoint index

The index is generated from SiYuan's source. After upgrading SiYuan:

```bash
python3 tools/gen_endpoints.py --tag v3.8.0
```

It shallow-clones the tag, re-parses every route and handler, and **refuses to write** a file
whose parameter coverage falls below 70% — a silent checkout or regex failure once shipped an
index in which an entire module's parameters were blank.

## Known limitations

- **`W`/`R` is a hint, not permission.** It comes from SiYuan's `CheckReadonly` middleware:
  ~17 endpoints marked `R` do mutate state (including `/api/system/exit`, which stops the
  kernel — guarded), and ~20 marked `W` are pure reads. `references/discovery.md` covers this.
- **Multipart, WebSocket, SSE and raw-byte endpoints are not callable** through `sy`. They are
  tagged in the index and the client explains why, pointing at the curl form where one exists.
- **Export endpoints return a path on the kernel host**, not the file. Fetch it over HTTP from
  `$SIYUAN_URL/<path>`.
- **The SQLite index rebuilds asynchronously.** A `SELECT` immediately after a write can return
  stale rows; chain writes off the ID the API returned rather than re-querying.

## Compatibility

Developed and verified against **SiYuan v3.7.3** on macOS (bash 3.2, BSD userland) against a
real instance. The kernel API is stable across patch releases; after a minor upgrade, regenerate
the index.

## Contributing

Issues and PRs welcome. If you touch `scripts/sy`, please verify against a real instance —
several bugs in this project's history were only reachable with non-ASCII content or a specific
SiYuan behaviour, and none of them showed up in isolated testing.

## License

[MIT](LICENSE)
