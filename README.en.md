# 🛡️ grok-privacy-guard

**[中文](README.md) · English**

> Stop xAI's official Grok CLI from **silently packaging and uploading your entire codebase to the cloud**, and **print one line on every launch telling you whether it uploaded**.
> macOS · zsh / bash. Scripts only read logs and write your own config — nothing is sent anywhere.

## What it does

- **Kills whole-repo upload locally**: disables the side channel that tars up your entire codebase (incl. git history), plus session-trace upload.
- **Prevents bypass**: locks grok's auto-update + checks the binary fingerprint; warns if the binary is swapped.
- **Visible every launch**: run `grok` and a 🟢 green line means "upload off, nothing sneaked out"; 🔴 red means alarm.
- **History**: one command reconstructs which repos of yours were uploaded before.

## Install

### Option A · yourself

```bash
git clone https://github.com/LeifDiao/grok-privacy-guard.git
cd grok-privacy-guard
bash install.sh
```

### Option B · let an AI agent install it

Send this to your coding agent (Claude Code / Cursor / …):

> Read https://github.com/LeifDiao/grok-privacy-guard , clone it and run `install.sh` for me.

`install.sh` is idempotent and self-backing-up, so the agent can just run it.

> New terminals activate automatically; for the current one run `source ~/grok-privacy/grok-guard.sh`.

## Commands

| Command | Purpose |
|---|---|
| `bash install.sh` | Install / update |
| `bash grok-guard-check.sh` | Spin up a fake repo and **actually test** whether upload is really disabled (**run after every grok upgrade**; auto re-pins the fingerprint) |
| `bash grok-guard-evidence.sh` | Show which repos were uploaded in the past (read-only) |
| `bash uninstall.sh` | Remove the sentinel (leaves grok alone; keeps config switches) |

## What you see on every launch

```
🛡️  grok-guard: upload disabled ✓  switches ✓  fingerprint ✓  — launching grok…
   … grok runs normally …
🛡️  grok-guard: no whole-repo upload this session · queue clean ✓
```

| Color | Meaning |
|---|---|
| 🟢 green | Upload disabled, nothing sneaked out this session |
| 🟡 yellow | Binary swapped / just upgraded → run `grok-guard-check.sh` to re-verify |
| 🔴 red | A switch was tampered with (prompts you) / this session likely triggered an upload (alarm) |

Bypass the sentinel: `GROK_GUARD=0 grok ...`　·　Alarms only, no green lines: `export GROK_GUARD_QUIET=1`

## What it changes / limitations

- Writes three lines to `~/.grok/config.toml` (auto-backed-up): `disable_codebase_upload=true`, `trace_upload=false`, `auto_update=false`.
- **No network-layer blocking** — it relies on grok honoring its own switches, which is why it adds the fingerprint pin + per-launch self-check. For physical blocking, use a per-process firewall (LuLu) or a container.
- Files you actively ask grok to read are still sent to the model (normal AI behavior, out of scope) — don't point it at sensitive files.

## Source / License

Mechanism revealed by [@cereblab](https://gist.github.com/cereblab/dc9a40bc26120f4540e4e09b75ffb547)'s packet analysis ([HN discussion](https://news.ycombinator.com/item?id=48877371)). MIT License.
