#!/usr/bin/env bash
# grok-privacy-guard 卸载：移除哨兵与注入行。默认保留 config.toml 的禁用开关（那是好东西）。
set -uo pipefail
DIR="${GROK_PRIVACY_DIR:-$HOME/grok-privacy}"
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  if grep -qF 'grok-guard.sh' "$rc"; then
    tmp="$(mktemp)"; grep -vF 'grok-guard.sh' "$rc" > "$tmp" && mv "$tmp" "$rc"
    echo "✓ 已从 $rc 移除哨兵注入行"
  fi
done
rm -f "$DIR/grok-guard.sh" "$DIR/grok-guard-check.sh" "$DIR/known-good.sha256"
rmdir "$DIR" 2>/dev/null || true
echo "✓ 哨兵已卸载。"
echo "ℹ config.toml 里的 disable_codebase_upload / trace_upload / auto_update 仍保留（建议留着）。"
echo "  如需还原，去 ~/.grok/config.toml 手动删，或用最近的 config.toml.bak.* 恢复。"
