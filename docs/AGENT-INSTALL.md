# Agent installation instructions

**This file is written for an AI agent.** If you are a human, see the
[README](../README.md) — you probably want the manual instructions there.

If a user asked you to install this skill, follow these steps in order. Do not
skip the verification step, and do not invent values the user has not given you.

---

## Step 1 — Work out where the skill goes

`SKILL.md` is a cross-agent standard, so this skill works unmodified on any of
these. Pick the directory for the agent **you** are running as:

| Agent | Skills directory |
|---|---|
| Claude Code | `~/.claude/skills/` |
| Codex CLI | `~/.codex/skills/` (personal) or `.codex/skills/` (project) |
| OpenClaw | any configured skills root — commonly `~/.openclaw/skills/` |
| Hermes Agent | `~/.hermes/skills/` |
| Anything else | wherever that agent discovers `SKILL.md` files |

If you are not certain which directory your host uses, check for an existing one
before asking the user:

```bash
for d in ~/.claude/skills ~/.codex/skills ~/.hermes/skills ~/.openclaw/skills; do
  [ -d "$d" ] && echo "found: $d"
done
```

If several exist, ask the user which agent they want it installed for. If none
exist, ask rather than creating a directory for the wrong tool.

**Alternative install routes** (the user must run these themselves — you cannot
run slash commands or interactive CLIs on their behalf). Offer whichever matches
their agent, then continue from Step 3:

- Claude Code plugin:
  ```
  /plugin marketplace add willjayyyy/siyuan-skill
  /plugin install siyuan@siyuan-skill
  ```
- Hermes Agent:
  ```
  hermes skills install https://github.com/willjayyyy/siyuan-skill --name siyuan
  ```

## Step 2 — Install the skill files

Substitute the directory you settled on in Step 1 for `$SKILLS_DIR`:

```bash
SKILLS_DIR=~/.claude/skills          # or ~/.codex/skills, ~/.hermes/skills, ...
tmp=$(mktemp -d)
git clone --depth 1 https://github.com/willjayyyy/siyuan-skill.git "$tmp"
mkdir -p "$SKILLS_DIR"
rm -rf "$SKILLS_DIR/siyuan"
cp -R "$tmp/skills/siyuan" "$SKILLS_DIR/siyuan"
chmod +x "$SKILLS_DIR/siyuan/scripts/sy"
rm -rf "$tmp"
```

If `$SKILLS_DIR/siyuan` already existed, say so — the user may have local edits
worth preserving.

Some agents only pick up new skills at session start. If yours does, tell the
user to restart it once installation is complete.

## Step 3 — Collect the connection details

You need two values. **Ask the user; never guess, never scan the network, and
never default to localhost.**

1. **SiYuan URL** — e.g. `http://192.168.1.10:6806` or `https://siyuan.example.com`.
   No trailing slash.
2. **API token** — the user finds it in SiYuan under **Settings → About → API token**.

Tell them the token grants full read/write access to the entire library, so they
should paste it only if they are comfortable with it living in a local file.

If the user has an existing config, read it rather than asking again:

```bash
cat "${SIYUAN_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/siyuan/env}" 2>/dev/null
```

## Step 4 — Write the config

The config lives **outside** the skill directory so the skill stays shareable.
Resolve the path the same way the client does:

1. `$SIYUAN_CONF` if set
2. `$XDG_CONFIG_HOME/siyuan/env` if `XDG_CONFIG_HOME` is set
3. `$APPDATA/siyuan/env` on Windows (Git Bash / MSYS2 / Cygwin)
4. `$HOME/.config/siyuan/env` otherwise

```bash
conf="${SIYUAN_CONF:-${XDG_CONFIG_HOME:+$XDG_CONFIG_HOME/siyuan/env}}"
conf="${conf:-${APPDATA:+$APPDATA/siyuan/env}}"
conf="${conf:-$HOME/.config/siyuan/env}"
mkdir -p "$(dirname "$conf")"
umask 077
cat > "$conf" <<EOF
SIYUAN_URL=<the url the user gave you>
SIYUAN_TOKEN=<the token the user gave you>
EOF
chmod 600 "$conf"
```

**Do not echo the token back** into the conversation after writing it, and do not
put it in a command line where it would show up in shell history or `ps` — use a
heredoc as above.

Optional settings the user may want later (leave them out unless asked):

```
SIYUAN_MAX_BYTES=8192   # response truncation limit
SIYUAN_TIMEOUT=30       # curl timeout, seconds
```

## Step 5 — Verify

```bash
"$SKILLS_DIR/siyuan/scripts/sy" nb
```

Expected: one tab-separated line per notebook (`<id>\t<name>`).

If it fails, map the error rather than guessing:

| Error | Meaning | What to do |
|---|---|---|
| `SIYUAN_URL and SIYUAN_TOKEN not configured` | config not found at the resolved path | re-check Step 4; print the path the client expects |
| `token rejected` (HTTP 401/403) | wrong token | ask the user to re-copy it from Settings → About |
| `cannot reach <url>` | wrong host/port, instance down, or firewalled | confirm the URL, ask the user to open it in a browser |
| `config exists but is not readable` | permissions | `ls -l` the file, fix ownership |

Then confirm reads and the guard rail work:

```bash
# read path
"$SKILLS_DIR/siyuan/scripts/sy" sql "SELECT count(*) n FROM blocks"

# guard rail — MUST print REFUSED and exit 3; never pass -y here
"$SKILLS_DIR/siyuan/scripts/sy" /api/filetree/removeDocByID -d '{"id":"x"}'
```

## Step 6 — Report back

Tell the user:

- where the skill was installed and where the config was written
- which notebooks were found (names only — do not dump IDs unless asked)
- that the skill now loads automatically whenever they mention SiYuan, saving
  something to their notes, or looking something up in them
- that destructive operations will be refused until they confirm explicitly

## Rules while installing

- **Never write to the user's SiYuan library during installation.** Verification
  is read-only. Do not create a test document to "check writes work".
- **Never pass `-y`** to a destructive endpoint during setup.
- **Never put the token on a command line** or echo it back.
- If anything is ambiguous — which agent directory, which of several SiYuan
  instances — ask rather than assume.
