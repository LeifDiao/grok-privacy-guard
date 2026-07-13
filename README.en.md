# 🛡️ grok-privacy-guard

**[中文](README.md) · English**

> One command to disable xAI's official Grok CLI from **silently packaging and uploading your entire codebase**, and **verify it to your face on every launch**.
>
> macOS / zsh + bash. All scripts are read-only against logs and only write your own local config — nothing is ever sent anywhere.

---

## 30-second version · how to use

- **What it fixes**: Grok CLI will, without your knowledge, tar up your **entire repository** and upload it to xAI's cloud. This tool **kills that upload locally** and, **every time you run `grok`, prints one line telling you "no repo was uploaded."**
- **Three steps**:
  1. `bash grok-guard-evidence.sh` — first, see whether you've been uploaded before
  2. `bash install.sh` — one shot: disable the upload + install the sentinel
  3. Use `grok` as usual: 🟢 green line = relax, 🔴 red line = pay attention
- **Not sure the switch actually took effect?** `bash grok-guard-check.sh` spins up a throwaway repo and really runs a turn to test whether it still uploads.

---

## Background: what happened

Security researcher **cereblab** did a wire-level packet capture of the official Grok CLI (`~/.grok`) and found that while `uploads_enabled=true`, it uses a **side channel independent of the model conversation** to package your **entire working directory (including git history)** and upload it to xAI's Google Cloud Storage bucket `grok-code-session-traces` — **regardless of whether the model read your files**. After it went public, xAI quietly switched it off via a **server-side remote flag** late on 2026-07-12.

- Wire-level analysis: https://gist.github.com/cereblab/dc9a40bc26120f4540e4e09b75ffb547
- Hacker News discussion: https://news.ycombinator.com/item?id=48877371

The core problem isn't "an AI reads files." It's that **this upload channel is on by default, undocumented, and remotely controlled by xAI's servers — so it can be silently turned back on for you at any time.**

## Step 1: check whether you were affected (read-only, changes nothing)

```bash
bash grok-guard-evidence.sh
```

It reconstructs the history from **your own local grok logs**. Real output from one machine looks like this 👇

```
Total whole-repo uploads started (repo_state.upload.start): 189   enqueued: 118   failed: 2

📦 Working directories that were packaged & uploaded (by upload count):
   [  84 x]  .../my-web-app
   [  61 x]  .../my-notes
   [  29 x]  .../my-desktop-app
   ...
🕒 Upload-switch state changes:
   2026-07-09        🔴 ON  (source=remote reason=proxy)   ← pushed by xAI server, uploading
   2026-07-12T23:53  🟢 OFF (source=remote)                ← xAI remotely disabled after exposure
   → current state:  🟢 OFF (source=config)                ← after this tool, YOU decide
```

`source=remote` = the switch is in xAI's hands; `source=config` = it's in yours. **That's exactly what this tool does.**

## Comparison

| | Grok CLI default | With grok-privacy-guard |
|---|---|---|
| Whole-repo upload | Controlled by xAI's server-side remote flag (`source=remote`) | Hard-disabled locally (`source=config`); xAI can't change it |
| Binary | Auto-updates, may be silently replaced | Pinned + fingerprint-checked; warns if swapped |
| How you know if it's uploading right now | You don't — you'd have to reverse-engineer traffic | **One green line on every launch**; red alarm if something's wrong |
| Past impact | Unknowable | `evidence` script reconstructs it in one command |

## What it does (three things)

1. **Hard-writes two kill switches** into `~/.grok/config.toml`:
   ```toml
   [harness]
   disable_codebase_upload = true   # kills the whole-repo before/after_codebase.tar.gz upload
   [telemetry]
   trace_upload = false             # kills the session trace / session_state upload
   ```
2. **Locks auto-update** (`[cli] auto_update = false`) + pins the binary's SHA-256, so xAI can't push a new binary that ignores the switches.
3. **Installs a launch sentinel**: wraps the `grok` command to self-check before and after every run.

## Install

```bash
git clone https://github.com/LeifDiao/grok-privacy-guard.git
cd grok-privacy-guard
bash install.sh          # idempotent; backs up your config.toml automatically
```

The installer: writes the kill switches (keeping your other config) → disables auto-update → pins the fingerprint → injects into `~/.zshrc`/`~/.bashrc` → runs a full verification.

> Already-open terminal: `source ~/grok-privacy/grok-guard.sh` to activate now; new terminals pick it up automatically.

## What you see on every launch

```
🛡️  grok-guard: upload disabled ✓  switches ✓  fingerprint ✓  — launching grok…
   … grok runs normally …
🛡️  grok-guard: no whole-repo upload this session · queue clean ✓
```

| Color | Meaning |
|---|---|
| 🟢 green | All good — upload disabled, nothing sneaked out this session |
| 🟡 yellow `fingerprint CHANGED` | Binary was swapped / you just upgraded → run `grok-guard-check.sh` to re-verify & re-pin |
| 🔴 red | A switch was tampered with (prompts you to confirm) / this session likely triggered an upload (alarm) |

- Temporarily bypass the sentinel: `GROK_GUARD=0 grok ...`
- Alarms only, no green lines: `export GROK_GUARD_QUIET=1`

## After upgrading grok

Since auto-update is off, upgrades are manual. After upgrading, **always** run:

```bash
bash ~/grok-privacy/grok-guard-check.sh
```

It spins up an isolated repo with fake data, **really runs a turn**, confirms the upload is still off (`uploads_enabled=False`), and **re-pins the fingerprint** — after which the sentinel stops warning. The key: it **doesn't trust what the config says, it observes what actually happens at runtime.**

## Stricter (optional, add as needed)

The config approach fundamentally "trusts the binary to obey its own switches." To go harder:

| Level | How | Strength |
|---|---|---|
| **This tool** | Local hard-disable + binary pin + per-launch self-check | Self-restraint + auditable |
| Tier 3 | Per-process outbound firewall (LuLu / Little Snitch): allow grok only to your model endpoint, deny the rest | Physically blocks the network |
| Tier 4 | Run grok in a container/VM with only the current repo mounted and egress locked to the model endpoint | Structural isolation |
| Ultimate | `grok logout` + uninstall | 100% |

## Uninstall

```bash
bash uninstall.sh   # removes only the sentinel + injected line; leaves grok alone; keeps the config kill switches by default
```

## Limitations (honestly)

- This tool does **not** do network-layer blocking; it relies on the grok binary honoring its own `disable_codebase_upload` switch — which is why it adds the fingerprint pin + per-launch self-check as backstops. For physical blocking, go to Tier 3/4.
- The model-conversation channel (files you actively ask it to read are sent to the model) is normal AI behavior and out of scope for these switches — **don't point grok at files holding sensitive content**.
- Currently targets macOS + zsh/bash, assuming the official `~/.grok` layout. PRs for other platforms welcome.

## How it works

Grok CLI logs a `trace.upload.decision` at the start of each turn; the `uploads_enabled` / `trace_upload_source` fields decide whether to upload and whose word wins. This tool flips `source` from `remote` to `config`, and uses the `repo_state.upload.start` event + the `~/.grok/upload_queue` staging dir as the hard source of truth for "did it actually upload." Every script only reads logs / writes your own config, with zero outbound calls.

## Credits

- [@cereblab](https://gist.github.com/cereblab), whose wire-level analysis first revealed this mechanism.

## License

MIT
