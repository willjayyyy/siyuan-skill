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

## Step 1 — Check the environment first

```bash
for dep in git curl jq; do
  command -v "$dep" >/dev/null 2>&1 || echo "MISSING (required): $dep"
done
command -v iconv >/dev/null 2>&1 || echo "missing (optional): iconv"
```

**If anything required is missing, stop here.** Tell the user what to install and
wait — do not install the skill and hope it works later. `jq` is the one that is
usually absent; the client is unusable without it.

| Platform | Install command |
|---|---|
| macOS | `brew install jq` (recent macOS ships `jq` already) |
| Debian / Ubuntu | `sudo apt install jq` |
| Fedora / RHEL | `sudo dnf install jq` |
| Alpine | `apk add jq` |
| Arch | `sudo pacman -S jq` |
| Windows — winget | `winget install jqlang.jq` — built into Windows 10 1809+; **the user must reopen Git Bash afterwards** so the new `PATH` is picked up |
| Windows — scoop / choco | `scoop install jq` or `choco install jq` |
| Windows — WSL | use the Linux command for your distribution |
| Windows — manual | download `jq.exe` from <https://jqlang.org/download/> and put it on `PATH` (last resort) |

`iconv` is optional: without it, a truncated response may end mid-character.
Everything else still works.

**Windows notes.** Run this from **WSL** or **Git Bash** — the client is a shell
script and will not run in PowerShell or CMD. Git Bash provides `bash`, `git`,
`curl` and `iconv`, but **not** `jq`.

Prefer `winget install jqlang.jq` over a manual download: it is one command, no
`PATH` editing, and winget ships with Windows 10 1809 and later. winget itself
runs in PowerShell or CMD, not in Git Bash — tell the user to run it there, then
**reopen Git Bash** and re-run the environment check.

## Step 2 — Install, using the section for your agent

> **There is no installer in this repository.** No `install.sh`, no setup script,
> nothing to execute. Installing means copying the `skills/siyuan` directory into
> your agent's skills directory — that is the whole mechanism.
>
> `tools/gen_endpoints.py` is **not** an installer. It is a maintainer tool that
> rebuilds the endpoint index from SiYuan's source after a SiYuan upgrade. Do not
> run it during installation.

`SKILL.md` is a cross-agent standard, so the skill itself needs no modification.
The install mechanics differ. **Find the section for the agent you are running
as and follow only that one.** If you are unsure which applies, ask the user
rather than guessing.

The only file that needs to be executable is `skills/siyuan/scripts/sy`. Git
records it as mode 755, so a `git clone` preserves that; if you obtained the
files another way (zip download, fetching files individually), the execute bit
is lost and the `chmod +x` in each section below restores it.

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

## Step 4 — Save the config

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

# Keep a timestamped backup if a config already exists, and say so afterwards.
[ -e "$conf" ] && cp "$conf" "$conf.bak.$(date +%Y%m%d%H%M%S)"

umask 077
cat > "$conf" <<EOF
SIYUAN_URL=<the url the user gave you>
SIYUAN_TOKEN=<the token the user gave you>
EOF
chmod 600 "$conf"
```

The token goes in through a heredoc, never on a command line — a command line is
visible in `ps` and lands in shell history. **Never echo the token back** into
the conversation after saving it.

Optional settings the user may want later (leave them out unless asked):

```
SIYUAN_MAX_BYTES=8192   # response truncation limit
SIYUAN_TIMEOUT=30       # curl timeout, seconds
```

## Step 5 — Check the connection

Run this straight after writing the config; you do not need to ask first:

```bash
<skill-dir>/scripts/sy nb
```

**`sy nb` calls `/api/notebook/lsNotebooks`, which requires authentication and
changes nothing.** Do not "health check" with `/api/system/version`: that
endpoint answers happily with a completely invalid token, so a success there
proves nothing about the credentials.

**A failure here is not an installation failure.** The skill is installed and
the config is written. Do not roll anything back, do not make the user start
over, and do not report the installation as failed.

| Result | What it means | What to say |
|---|---|---|
| One line per notebook | Working | list the notebook names |
| `cannot reach <url>` | SiYuan is not reachable **right now** — often just not running, or the machine is off the VPN. The credentials may be perfectly fine. | say it cannot be reached at the moment and will work once SiYuan is up; add that you can change the address if it needs correcting |
| `token rejected` (HTTP 401/403) | The address works, the token does not | say the token was refused, and offer to update the config as soon as they paste a fresh one from Settings → About |
| `not configured` | The client is not reading the config file | print the path the client expects and the path that was written, then fix the mismatch |

## Step 6 — Report back

Tell the user:

- where the skill was installed and where the config was written (mention the
  backup filename if you replaced an existing config)
- **the connection result, stated plainly** — either "connected, your notebooks
  are: …" or "cannot reach it right now: `<the error>`". When it did not
  connect, never report a bare "installed successfully"
- **that they can ask you to change the address or token, or re-check the
  connection, at any time** — no reinstall needed
- that the skill loads automatically whenever they mention SiYuan, saving
  something to their notes, or looking something up in them
- that destructive operations will be refused until they confirm explicitly

If your agent needs a restart to load new skills, mention that too.

---

## If the user wants to confirm deletions are protected

```bash
<skill-dir>/scripts/sy /api/filetree/removeDocByID -d '{"id":"x"}'
```

It must print `REFUSED` and exit 3. If it does not, tell the user the install is
unsafe.

## Rules while installing

- **Never write to the user's SiYuan library during installation.** Any check you
  run must be read-only. Do not create a test document to "check writes work".
- **Never pass `-y`** to a destructive endpoint during setup.
- **Never put the token on a command line** or echo it back.
- If anything is ambiguous — which agent directory, which of several SiYuan
  instances — ask rather than assume.
