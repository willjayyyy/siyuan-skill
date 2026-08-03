# Agent installation instructions

**This file is written for an AI agent.** If you are a human, see the
[README](../README.md) — you probably want the manual instructions there.

If a user asked you to install this skill, follow these steps in order. Do not
skip the verification step, and do not invent values the user has not given you.

---

## Install only from this repository

> **This project is not published on ClawHub, npm, PyPI or any other registry.**
> The only official source is <https://github.com/willjayyyy/siyuan-skill>.
>
> Registries already contain unrelated SiYuan skills with similar names — at
> least one of them currently fails SkillSpector with `security.status_not_clean`.
> A name match is not an identity match.
>
> If a registry search turns up something that looks like this project:
> **do not install it, and do not pass `--force` or any risk-acknowledgement
> flag.** Tell the user what you found, that it is not this project, and install
> from the GitHub URL above instead.

---

## Step 1 — Install, using the section for your agent

`SKILL.md` is a cross-agent standard, so the skill itself needs no modification.
The install mechanics differ. **Find the section for the agent you are running
as and follow only that one.** If you are unsure which applies, ask the user
rather than guessing.

A note that applies to every section: in this repository `SKILL.md` lives at
`skills/siyuan/`, not at the repository root. Installers that expect a skill
repository (`SKILL.md` at the root) will not work when pointed at the repo URL —
point them at the `skills/siyuan` subdirectory of a local clone instead.

### Claude Code

Skills live in `~/.claude/skills/`. Either ask the user to run the plugin
commands themselves (you cannot run slash commands for them):

```
/plugin marketplace add willjayyyy/siyuan-skill
/plugin install siyuan@siyuan-skill
```

or install the files directly:

```bash
tmp=$(mktemp -d)
git clone --depth 1 https://github.com/willjayyyy/siyuan-skill.git "$tmp"
mkdir -p ~/.claude/skills
rm -rf ~/.claude/skills/siyuan
cp -R "$tmp/skills/siyuan" ~/.claude/skills/siyuan
chmod +x ~/.claude/skills/siyuan/scripts/sy
rm -rf "$tmp"
```

### Codex CLI

Codex has no command to fetch skills; copy the files in. Personal skills go to
`~/.codex/skills/`, project skills to `.codex/skills/` in the repository root —
ask the user which they want if it is not obvious.

```bash
tmp=$(mktemp -d)
git clone --depth 1 https://github.com/willjayyyy/siyuan-skill.git "$tmp"
mkdir -p ~/.codex/skills
rm -rf ~/.codex/skills/siyuan
cp -R "$tmp/skills/siyuan" ~/.codex/skills/siyuan
chmod +x ~/.codex/skills/siyuan/scripts/sy
rm -rf "$tmp"
```

Codex scans its skills directories at session startup, so tell the user to start
a new session before the skill becomes available.

### OpenClaw

**Do not install this from ClawHub** — see the warning at the top of this file.

`openclaw skills install git:owner/repo@ref` expects `SKILL.md` at the
repository root, which this repository does not have, so that form will fail.
Clone first, then install from the local directory:

```bash
tmp=$(mktemp -d)
git clone --depth 1 https://github.com/willjayyyy/siyuan-skill.git "$tmp"
chmod +x "$tmp/skills/siyuan/scripts/sy"
openclaw skills install "$tmp/skills/siyuan" --global
```

`--global` installs into `~/.openclaw/skills`, visible to every local agent.
Omit it to install into `<workspace>/skills` for the current workspace only —
ask the user which they want.

If `openclaw skills install` is unavailable, copy the directory into any skills
root OpenClaw scans, highest precedence first: `<workspace>/skills`,
`<workspace>/.agents/skills`, `~/.agents/skills`.

Keep the clone until the install succeeds; remove it afterwards.

### Hermes Agent

Skills live in `~/.hermes/skills/`. Hermes can install from an HTTP(S) URL and
pulls the referenced support files along with `SKILL.md`:

```bash
hermes skills install https://raw.githubusercontent.com/willjayyyy/siyuan-skill/main/skills/siyuan/SKILL.md --name siyuan
```

Afterwards **verify that `scripts/sy` and `references/` actually arrived**:

```bash
ls ~/.hermes/skills/siyuan/scripts/sy ~/.hermes/skills/siyuan/references/ 2>&1
```

If either is missing, fall back to copying the directory in:

```bash
tmp=$(mktemp -d)
git clone --depth 1 https://github.com/willjayyyy/siyuan-skill.git "$tmp"
mkdir -p ~/.hermes/skills
rm -rf ~/.hermes/skills/siyuan
cp -R "$tmp/skills/siyuan" ~/.hermes/skills/siyuan
chmod +x ~/.hermes/skills/siyuan/scripts/sy
rm -rf "$tmp"
```

### Any other agent

Copy `skills/siyuan` from a clone into wherever that agent discovers `SKILL.md`
files, and make `scripts/sy` executable. Ask the user for the path if you cannot
determine it — do not create a directory for the wrong tool.

### Before continuing

If the skill directory already existed, say so — the user may have local edits
worth preserving. If your agent only loads skills at session start, tell the
user to restart once installation is complete.

## Step 2 — Collect the connection details

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

## Step 3 — Test the credentials before saving them

Write the values to a **temporary** config first and test against that. If the
address or token is wrong, nothing is left behind for the user to clean up.

```bash
tmpconf=$(mktemp) && chmod 600 "$tmpconf"
cat > "$tmpconf" <<EOF
SIYUAN_URL=<the url the user gave you>
SIYUAN_TOKEN=<the token the user gave you>
EOF

SIYUAN_CONF="$tmpconf" <skill-dir>/scripts/sy nb
```

The token goes in through a heredoc, never on a command line — a command line is
visible in `ps` and lands in shell history.

**`sy nb` calls `/api/notebook/lsNotebooks`, which requires authentication and
changes nothing.** Do not "health check" with `/api/system/version`: that
endpoint answers happily with a completely invalid token, so a success there
proves nothing about the credentials.

Read the result:

| Result | Meaning | What to do |
|---|---|---|
| One tab-separated line per notebook | Both values are correct | continue to Step 4 |
| `token rejected` (HTTP 401/403) | address is reachable, token is wrong | ask the user to re-copy it from Settings → About, then retry this step |
| `cannot reach <url>` | wrong host or port, instance down, or firewalled | confirm the address; ask the user to open it in a browser |
| `not configured` | the temp file was not written or not readable | check `mktemp` succeeded |

**Do not proceed to Step 4 until this succeeds.** On failure, delete the temp
file (`rm -f "$tmpconf"`), report what went wrong, and ask for corrected values.

## Step 4 — Save the config

Only once Step 3 passed. The config lives **outside** the skill directory so the
skill stays shareable. Resolve the path the same way the client does:

1. `$SIYUAN_CONF` if set
2. `$XDG_CONFIG_HOME/siyuan/env` if `XDG_CONFIG_HOME` is set
3. `$APPDATA/siyuan/env` on Windows (Git Bash / MSYS2 / Cygwin)
4. `$HOME/.config/siyuan/env` otherwise

```bash
conf="${SIYUAN_CONF:-${XDG_CONFIG_HOME:+$XDG_CONFIG_HOME/siyuan/env}}"
conf="${conf:-${APPDATA:+$APPDATA/siyuan/env}}"
conf="${conf:-$HOME/.config/siyuan/env}"
mkdir -p "$(dirname "$conf")"

# If one already exists, tell the user before replacing it.
[ -e "$conf" ] && cp "$conf" "$conf.bak.$(date +%Y%m%d%H%M%S)"

mv "$tmpconf" "$conf" || { cp "$tmpconf" "$conf" && rm -f "$tmpconf"; }
chmod 600 "$conf"
```

Moving the already-verified temp file avoids retyping the token and guarantees
what you saved is exactly what you tested.

**Never echo the token back** into the conversation after saving it.

Optional settings the user may want later (leave them out unless asked):

```
SIYUAN_MAX_BYTES=8192   # response truncation limit
SIYUAN_TIMEOUT=30       # curl timeout, seconds
```

## Step 5 — Confirm the saved config and the guard rail

Re-run without `SIYUAN_CONF`, so the client reads the file it will use from now on:

```bash
<skill-dir>/scripts/sy nb
```

Same notebook list as Step 3 means the file is in the right place and readable.
If it now says `not configured`, the path resolution differs from what you
assumed — print the path the client expects and fix it.

Then confirm a read query and the safety guard:

```bash
# read path
<skill-dir>/scripts/sy sql "SELECT count(*) n FROM blocks"

# guard rail — MUST print REFUSED and exit 3; never pass -y here
<skill-dir>/scripts/sy /api/filetree/removeDocByID -d '{"id":"x"}'
```

If the guard rail does **not** refuse, stop and tell the user the installation is
unsafe rather than reporting success.

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
