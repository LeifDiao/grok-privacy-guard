# 🛡️ grok-privacy-guard

**[中文](README.md) · English**

> A codebase-privacy guard for Grok CLI: prevents your repository from being uploaded without your knowledge, and **detects the upload state on every launch and alerts you**.
> macOS · zsh / bash. Scripts only read logs and write your own config — nothing is sent anywhere.

## What it does

- **Prevents whole-repo upload**: stops grok from packaging and uploading your entire codebase (incl. git history) in the background, and blocks session-trace upload too.
- **Prevents bypass**: locks grok's auto-update + checks the binary fingerprint; alerts if the binary is replaced.
- **Launch detection**: self-checks every time you run grok — 🟢 green = guard active, no upload this session; 🔴 red = alert.
- **History detection**: one command checks whether any of your repos were uploaded in the past.

## Install

### Option A · yourself

```bash
git clone https://github.com/LeifDiao/grok-privacy-guard.git
cd grok-privacy-guard
bash install.sh
```

### Option B · let an AI agent install it

Send this to your coding agent (Claude Code / Cursor / …):

> Read https://github.com/LeifDiao/grok-privacy-guard , clone it and run `install.sh` for me, and **keep the sentinel visible on every launch — do not enable silent mode**.

`install.sh` is idempotent and self-backing-up, so the agent can just run it.

> ⚠️ **Make sure it announces itself.** By default the sentinel prints a status line before every grok launch (🟢 guard active / 🔴 alert). When an agent installs it, require it to **keep that line visible and NOT enable silent mode (`GROK_GUARD_QUIET`)** — being able to see it every single time is exactly what makes it trustworthy. Don't let it "install quietly and go dark."

> New terminals activate automatically; for the current one run `source ~/grok-privacy/grok-guard.sh`.

## Commands

| Command | Purpose |
|---|---|
| `bash install.sh` | Install / update |
| `bash grok-guard-check.sh` | Spin up a fake repo and **actually test** whether the guard is in effect (**run after every grok upgrade**; auto re-pins the fingerprint) |
| `bash grok-guard-evidence.sh` | Check whether any repos were uploaded in the past (read-only) |
| `bash uninstall.sh` | Remove the sentinel (leaves grok alone; keeps config protection) |

## What you see on every launch

```
🛡️  grok-guard: upload guard active ✓  switches ✓  fingerprint ✓  — launching grok…
   … grok runs normally …
🛡️  grok-guard: no whole-repo upload this session · queue clean ✓
```

| Color | Meaning |
|---|---|
| 🟢 green | Guard active, no upload this session |
| 🟡 yellow | Binary replaced / just upgraded → run `grok-guard-check.sh` to re-verify |
| 🔴 red | Protection was altered (prompts you) / an upload likely happened this session (alert) |

Bypass the sentinel: `GROK_GUARD=0 grok ...`　·　Alerts only, no green lines: `export GROK_GUARD_QUIET=1`

## What it changes / limitations

- Writes three lines to `~/.grok/config.toml` (auto-backed-up): `disable_codebase_upload=true`, `trace_upload=false`, `auto_update=false`.
- **No network-layer blocking** — it relies on grok honoring its own switches, which is why it adds the fingerprint check + per-launch detection as backstops. For physical blocking, use a per-process firewall (LuLu) or a container.
- Files you actively ask grok to read are still sent to the model (normal AI behavior, out of scope) — don't point it at sensitive files.

## Source / License

The underlying mechanism is documented in [@cereblab](https://gist.github.com/cereblab/dc9a40bc26120f4540e4e09b75ffb547)'s packet analysis ([HN discussion](https://news.ycombinator.com/item?id=48877371)). MIT License.
