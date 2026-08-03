<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

# SiYuan Agent Skill

**Let your AI assistant work with your [SiYuan](https://github.com/siyuan-note/siyuan) notes — read them, write them, keep them up to date.**

English · [简体中文](README.zh-CN.md)

[Install](#install) · [Supported assistants](#which-ai-assistants-work) · [Configure](#connect-it-to-your-siyuan) · [Safety](#your-notes-stay-safe)

</div>

---

Your notes live in SiYuan. Your work happens with an AI assistant. This connects the two.

Once installed, you just talk normally:

> **You:** Write up what we just figured out about the memory leak and put it in my tech notes.
>
> **Assistant:** Created *"2026-08-03 Memory leak in the worker pool"* under Tech Notes — root cause, the three things we ruled out, and the fix. Tagged `#debugging` `#golang`.

> **You:** What did I write about our Kubernetes upgrade?
>
> **Assistant:** Three notes mention it. The one from June has your rollback checklist; the August one says the CNI plugin was the blocker.

> **You:** Add today's outcome to that August note.
>
> **Assistant:** Appended a "Resolution" section to *"K8s 1.29 upgrade"*.

No copy-pasting, no switching windows, no exporting and re-importing.

## What it can do

Everything SiYuan itself can do, because it speaks the same API the SiYuan app uses — all 540 of its endpoints.

**Write** — create notes from a conversation, append sections to existing ones, insert content at a specific place, rewrite a paragraph, upload images and attachments.

**Read** — search across your whole library by keyword, tag or content, pull a document's outline, follow links between notes, check what references what.

**Update** — rename, move between notebooks, restructure, retag, edit attributes, find and replace across a set of documents.

**Organise** — create and manage notebooks, maintain tags, spot duplicates, find orphaned notes, export to Markdown, HTML, Word or PDF.

## Which AI assistants work

`SKILL.md` is an open standard, so this works across assistants without modification:

| Assistant | Where skills live | Status |
|---|---|---|
| **Claude Code** | `~/.claude/skills/` | Supported |
| **Codex CLI** | `~/.codex/skills/` | Supported |
| **OpenClaw** | any `SKILL.md` under a configured root | Supported |
| **Hermes Agent** | `~/.hermes/skills/` | Supported |
| Others | wherever that assistant reads `SKILL.md` from | Works if it reads `SKILL.md` and can run a shell command |

Any assistant that can read a `SKILL.md` and run a shell command can use this.

## Install

### Let your assistant install it

Copy this one line and send it to your AI assistant:

```text
Install this for me, following: https://github.com/willjayyyy/siyuan-skill/blob/main/docs/AGENT-INSTALL.md
```

It handles installation and setup, asking you for your SiYuan address and API token along the way.

### Install it yourself

Download the skill and copy it into your assistant's skills folder:

```bash
git clone https://github.com/willjayyyy/siyuan-skill.git
cp -R siyuan-skill/skills/siyuan ~/.claude/skills/siyuan    # swap the directory for your assistant — see the install guide
chmod +x ~/.claude/skills/siyuan/scripts/sy
```

**Claude Code users** can also install it as a plugin:

```text
/plugin marketplace add willjayyyy/siyuan-skill
/plugin install siyuan@siyuan-skill
```

## Updating

Installing again *is* the update — the install commands replace the old copy.
Ask your assistant:

```text
Update my SiYuan skill to the latest version
```

Your address and token are stored outside the skill folder, so **updating never
asks you to configure anything again**, and it never touches your notes. If your
assistant only loads skills at startup, restart it afterwards.

## Connect it to your SiYuan

If you installed via your assistant, this is already done. Read on only if you installed manually or want to point it at a different instance.

You need two things:

- **Your SiYuan address** — something like `http://192.168.1.10:6806`
- **An API token** — find it in SiYuan under **Settings → About → API token**

Ask your assistant, and one line is enough:

```text
Set up the SiYuan skill to connect to my notes
```

To do it yourself, create a file with your address and token. Where it goes depends on your system:

| System | File location |
|---|---|
| macOS / Linux | `~/.config/siyuan/env` |
| Windows | `%APPDATA%\siyuan\env` |

The file has two lines:

```text
SIYUAN_URL=http://192.168.1.10:6806
SIYUAN_TOKEN=your-api-token-here
```

On macOS and Linux, restrict it to your account: `chmod 600 ~/.config/siyuan/env`

That's it. Your assistant will pick it up the next time you mention your notes.

## Your notes stay safe

Handing an AI assistant write access to years of notes deserves real safeguards. This skill has them:

**Deleting anything requires your explicit approval.** Sixty-five operations that destroy data — removing documents, deleting notebooks, library-wide find-and-replace, restoring old snapshots — are blocked by default. The assistant has to come back and ask you.

**You get real numbers before you approve.** Rather than a vague "delete this note?", you see what it actually affects: *this document, 9 blocks inside it, 0 other notes linking to it.* You decide with facts.

**A few operations are dangerous in ways that aren't obvious.** Closing the built-in user guide notebook permanently deletes it. One API call stops SiYuan's background service entirely. Both are caught and explained rather than silently executed.

**Reading can't accidentally write.** Database queries are locked to read-only at the server, so a malformed query fails loudly instead of quietly changing something.

**Your token stays out of sight.** It's never placed on a command line where other programs could read it, and it's stored outside the skill folder so the skill itself stays safe to share.

**Nothing is guessed.** If the configuration is missing, it stops and tells you. It will never quietly connect to some other SiYuan that happens to be running on your machine.

> **One thing to know:** a SiYuan API token grants full access to your entire library. Keep the config file private, and if you expose SiYuan outside your home network, put proper authentication in front of it.

## Requirements

- A running SiYuan instance reachable over the network — self-hosted, Docker, or the desktop app
- Tested against SiYuan **v3.7.3**
- `curl` and `jq` on your `PATH`

`jq` is the one people are usually missing — recent macOS ships it, most Linux
distributions do not:

| Platform | Getting `jq` | Notes |
|---|---|---|
| macOS | `brew install jq` | recent versions already include it |
| Debian / Ubuntu | `sudo apt install jq` | |
| Fedora / RHEL | `sudo dnf install jq` | |
| Alpine / Arch | `apk add jq` / `sudo pacman -S jq` | |
| Windows | `winget install jqlang.jq` | winget is built into Windows 10 1809+; run it in PowerShell, then reopen Git Bash |
| Windows, WSL | use your distribution's command | works like Linux |

The skill checks for both on startup and prints the exact install command if one
is missing, so you will not get a confusing error later.

**Windows:** use **WSL** or **Git Bash** — the client is a shell script, so
PowerShell and CMD are not supported. Git for Windows brings `bash`, `git`,
`curl` and `iconv`; `jq` is the one thing you add, with a single
`winget install jqlang.jq` in PowerShell followed by reopening Git Bash.

**No Python or Node runtime is needed** — the client is a single shell script.
(`tools/gen_endpoints.py` uses Python, but that is a maintainer script for
rebuilding the endpoint index; you never need to run it.)

## Why this isn't an MCP server

MCP servers have to declare every operation up front. SiYuan has 540 of them and publishes no machine-readable spec, which is why existing SiYuan MCP servers cover only a dozen or two.

A skill works differently: one universal client plus a searchable index of every endpoint. Coverage is complete by design, and the detailed documentation only loads when it's actually relevant — so a typical note-taking request costs a fraction of the context an equivalent MCP server would occupy in every session, whether you use it or not.

## For the curious

- [How the skill is built](docs/DESIGN.md) — architecture, safety design, token budget
- [Installation guide for assistants](docs/AGENT-INSTALL.md) — the instructions your AI follows
- [`skills/siyuan/`](skills/siyuan/) — the skill itself; the `references/` folder is what your assistant reads when it needs API details

Upgrading SiYuan? Regenerate the endpoint index with `python3 tools/gen_endpoints.py --tag v3.8.0`.

## Contributing

Issues and pull requests welcome. If you change the client script, please test against a real SiYuan instance — several bugs in this project's history only appeared with non-ASCII content or specific SiYuan behaviour, and none of them showed up in isolated testing.

## License

[MIT](LICENSE)
