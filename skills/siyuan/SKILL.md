---
name: siyuan
description: Use when reading from or writing to SiYuan — archiving knowledge/notes into SiYuan, searching the note database, creating or updating documents and blocks, managing notebooks, tags, attributes or assets. Covers the SiYuan kernel HTTP API (540 JSON endpoints) via a universal client.
---

# SiYuan Kernel API

`scripts/sy` — next to this file — calls **any** JSON endpoint of the kernel API
(540 of them). Set `sy` to its path once, then use `$sy` throughout:

```bash
sy="<this skill's directory>/scripts/sy"     # e.g. ~/.claude/skills/siyuan/scripts/sy
```

Credentials come from a config file resolved in this order: `$SIYUAN_CONF`,
`$XDG_CONFIG_HOME/siyuan/env`, `$APPDATA/siyuan/env` (Windows),
`$HOME/.config/siyuan/env`. It holds `SIYUAN_URL` and `SIYUAN_TOKEN`; both may
also be passed as environment variables, which take precedence. **There is no
default URL** — if nothing is configured, `sy` errors out with the path it
expected rather than guessing at localhost.

## Always go through `sy`. Never call the API directly.

Every safety property of this skill lives in `sy`: the refusal of 65 destructive
endpoints, the byte-exact endpoint allowlist that blocks path-normalisation
bypasses, the blast-radius report, read-only enforcement on SQL, response
truncation, and keeping the token off the command line.

**A hand-rolled request with `curl`, `Invoke-RestMethod`, `requests`, `fetch` or
anything else has none of that.** It will happily delete a notebook. So:

- Do **not** reimplement the client because `sy` failed to start — fix the
  invocation instead (see below), or tell the user it is broken.
- Do **not** read the config file yourself to extract the URL and token.
- Do **not** call `/api/...` directly, not even for a read. A read today becomes
  a copy-pasted delete tomorrow.

The one documented exception is `/api/asset/upload`, which is multipart and
therefore cannot go through `sy` — `references/asset.md` gives the exact curl
form, and it writes nothing destructive.

### Getting `sy` to run

`sy` is a shell script. Run it with a shell that can actually execute it:

| Situation | What to do |
|---|---|
| macOS / Linux | `"$sy" nb` — it is executable, no interpreter prefix needed |
| Windows, inside Git Bash | same as above |
| Windows, from PowerShell or CMD | **`bash` resolves to WSL's `bash.exe` and will fail if WSL is not set up.** Use Git Bash explicitly: `& "C:\Program Files\Git\bin\bash.exe" "<path>\sy" nb` |

If none of these work, report the problem to the user. Do not work around it by
talking to the API yourself.

## Two rules that matter most

**1. Never fetch whole documents.** `/api/filetree/getDoc` returns raw DOM —
typically 50–110 KB (~15–30k tokens). Use SQL column projection instead:

```bash
$sy sql "SELECT id,content FROM blocks WHERE root_id='<docID>' AND type='h'"
```

But **SQL has no document-order column** — `sort` is a block-type rank, so
`ORDER BY sort` scrambles the reading order. When order matters use
`/api/block/getChildBlocks` or `/api/outline/getDocOutline`.

`sy` truncates any response over 8 KB and tells you to narrow it. When that
happens, **narrow the query — do not re-run with `-r` or a bigger `--max`.**

**2. Destructive endpoints are refused** (exit 3) unless `-y` is passed. `sy`
prints the blast radius (affected docs, descendant blocks, inbound refs). Relay
that to the user, get an explicit OK, then re-run with `-y`. Never add `-y`
preemptively.

The endpoint must be a byte-exact entry in `data/endpoints.tsv` — dot-segments,
`%`-escapes and unknown paths are rejected outright, because those forms would
otherwise slip past the danger check and still reach the real handler. If a call
is refused as unknown, look it up with `sy api -g <keyword>`; only if SiYuan was
upgraded past v3.7.3 is `SIYUAN_ALLOW_UNKNOWN=1` the right answer.

## Commands

```bash
$sy nb                                  # notebooks: id + name
$sy sql "SELECT ..."                    # query the index (see references/query-sql.md)
$sy newdoc <nbID> <hpath> <md-file|->   # create doc from markdown (no quoting hell)
$sy append <parentID> <md-file|->       # append markdown to a container block
$sy <endpoint> -d '<json>' [-q '<jq>']  # any of the 540 JSON endpoints
$sy api <module> | -g <pat> | -w        # find endpoints + their param names
```

Flags: `-d @file` / `-d @-` reads the body from a file or stdin (use this for
anything containing quotes or newlines). `-q` applies a jq filter to `.data`.
`-r` prints the full `{code,msg,data}` envelope untruncated — still guard-railed,
and it does not combine with `--max`. `-y` confirms a destructive endpoint.
`--max N` raises the truncation limit (integer bytes).

## Where to look things up

Read **one** file below — only the one you need. Do not read them all.

| Task | File |
|---|---|
| Query the note index, table schemas, block types | `references/query-sql.md` |
| Create / move / rename / delete documents | `references/doc-crud.md` |
| Insert / update / delete blocks, daily notes | `references/block-crud.md` |
| Full-text search, tags, refs, templates | `references/search.md` |
| Block attributes, tags, bookmarks, memos | `references/attr-tag.md` |
| Upload images and attachments | `references/asset.md` |
| Export to md/pdf/docx, import | `references/export-import.md` |
| Notebooks, incl. encrypted/locked ones | `references/notebook.md` |
| An endpoint not documented above | `references/discovery.md` |

`sy api` covers the other ~450 endpoints: `$sy api -g <keyword>` prints the
endpoint, its HTTP method, a `W`/`R` hint and its parameter names. **`W`/`R`
comes from SiYuan's middleware, not from behaviour — it is not permission to
call something.** Read `references/discovery.md` before calling an endpoint that
has no reference file.

## Facts worth knowing up front

- Every ID is `yyyyMMddHHmmss-xxxxxxx`, so `ORDER BY id` == order by creation time.
- `hpath` is the human path (`/Notes/2026-08-03-title`); `path` is the internal
  `.sy` file path. **A `path` argument usually means the internal path**
  (`listDocsByPath`, `createDoc`, `removeDoc`, `heading2Doc`) —
  `createDocWithMd` is the exception where it means hpath. Passing an hpath to
  the others fails with `no such file or directory`. Check the reference; never
  guess.
- Nearly all endpoints are POST + JSON returning `{code,msg,data}`; `sy` unwraps
  `.data` and turns `code!=0` into a non-zero exit. The exceptions (a few GET-only
  endpoints, multipart uploads, WebSocket/SSE streams, and handlers that return
  raw bytes like `/api/file/getFile`) are flagged in `sy api` output; use `-r`
  for anything that does not return the standard envelope.
- The SQLite index rebuilds **asynchronously**. A `SELECT` immediately after a
  write or delete can return stale rows — it bit this skill twice during testing
  (an outline query came back empty, a delete looked like it left 12 blocks).
  Re-query rather than concluding failure.
- Because of that lag: **chain writes off the ID the API returned, never off a
  fresh `SELECT`.** `newdoc` prints the new document ID — feed that straight into
  `append` or `setBlockAttrs`. Looking it back up races the indexer.
- Verify the result of a write with a projected `sy sql`, never with `getDoc`.
