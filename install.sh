#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# grok-privacy-guard · 一键安装
#   1) 把禁用开关幂等写进 ~/.grok/config.toml（保留你其它配置，自动备份）
#   2) 关掉 grok 自动更新（防止二进制被静默替换）
#   3) 装启动哨兵到 ~/grok-privacy/ 并注入 ~/.zshrc / ~/.bashrc
#   4) 固定二进制指纹 + 跑一次完整复检
# 自定义安装目录：  GROK_PRIVACY_DIR=/path ./install.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DIR="${GROK_PRIVACY_DIR:-$HOME/grok-privacy}"
GROK_HOME="${GROK_HOME:-$HOME/.grok}"
CFG="$GROK_HOME/config.toml"
BIN="$GROK_HOME/bin/grok"
g(){ printf "\033[32m%s\033[0m\n" "$1"; }
y(){ printf "\033[33m%s\033[0m\n" "$1"; }

echo "══════════════ grok-privacy-guard 安装 ══════════════"

# 0) 前提
if [ ! -x "$BIN" ] && ! command -v grok >/dev/null 2>&1; then
  y "未检测到 grok CLI（$BIN）。请先安装 grok，再运行本安装器。"; exit 1
fi
[ -x "$BIN" ] || BIN="$(command -v grok)"
echo " grok: $("$BIN" --version 2>/dev/null)"

# 1) 装脚本
mkdir -p "$DIR"
cp "$SRC/grok-guard.sh" "$SRC/grok-guard-check.sh" "$DIR/"
chmod +x "$DIR/grok-guard-check.sh"
g " ✓ 脚本已装到 $DIR"

# 2) patch config.toml（幂等 + 备份）
mkdir -p "$GROK_HOME"; [ -f "$CFG" ] || : > "$CFG"
cp "$CFG" "$CFG.bak.$(date +%Y%m%d%H%M%S)"
python3 - "$CFG" <<'PY'
import sys, re
path=sys.argv[1]
lines=open(path).read().split('\n')
want=[('cli','auto_update','false'),
      ('harness','disable_codebase_upload','true'),
      ('telemetry','trace_upload','false')]
def bounds(lines, sec):
    hdr=re.compile(r'^\s*\['+re.escape(sec)+r'\]\s*$'); anyh=re.compile(r'^\s*\[')
    start=next((i for i,l in enumerate(lines) if hdr.match(l)), None)
    if start is None: return None
    end=next((j for j in range(start+1,len(lines)) if anyh.match(lines[j])), len(lines))
    return (start,end)
for sec,key,val in want:
    kre=re.compile(r'^\s*'+re.escape(key)+r'\s*=')
    b=bounds(lines,sec)
    if b:
        s,e=b
        if any(kre.match(lines[k]) for k in range(s+1,e)):
            for k in range(s+1,e):
                if kre.match(lines[k]): lines[k]=f'{key} = {val}'
        else:
            lines.insert(s+1, f'{key} = {val}')
    else:
        if lines and lines[-1].strip()!='': lines.append('')
        lines += [f'[{sec}]', f'{key} = {val}']
open(path,'w').write('\n'.join(lines))
PY
g " ✓ config.toml 已写入禁用开关（disable_codebase_upload / trace_upload / auto_update；原文件已备份）"

# 3) 固定指纹
shasum -a 256 "$GROK_HOME/bin/grok" 2>/dev/null | awk '{print $1}' > "$DIR/known-good.sha256" || true
g " ✓ 已固定二进制指纹"

# 4) 注入 shell rc（幂等，覆盖 zsh 与 bash）
HOMELIT="$DIR"; case "$DIR" in "$HOME"/*) HOMELIT="\$HOME/${DIR#"$HOME"/}";; esac
LINE="[ -f \"$HOMELIT/grok-guard.sh\" ] && . \"$HOMELIT/grok-guard.sh\"  # grok-privacy-guard"
RCS="$HOME/.zshrc"; touch "$HOME/.zshrc"                       # zsh：macOS 默认
for br in "$HOME/.bashrc" "$HOME/.bash_profile"; do [ -f "$br" ] && RCS="$RCS $br"; done
# 用 bash 但没有任何 bash 启动文件时，建 .bash_profile（macOS 登录 shell 读它，不读 .bashrc）
case "${SHELL:-}" in *bash*) [ -f "$HOME/.bashrc" ] || [ -f "$HOME/.bash_profile" ] || { touch "$HOME/.bash_profile"; RCS="$RCS $HOME/.bash_profile"; };; esac
added=""
for rc in $RCS; do
  if grep -qF 'grok-guard.sh' "$rc" 2>/dev/null; then :; else printf '\n%s\n' "$LINE" >> "$rc"; added="$added $rc"; fi
done
[ -n "$added" ] && g " ✓ 已注入哨兵:$added" || y " ℹ 哨兵注入行已存在，跳过"

# 5) 复检
echo; bash "$DIR/grok-guard-check.sh" || true

echo
g "✅ 安装完成。"
echo "  ⚠️ 关键最后一步——哨兵只对『新 shell』生效，当前窗口二选一让它立刻生效："
printf '     \033[1m▶ 最快： exec zsh\033[0m   （原地重载当前终端；bash 用户用 exec bash）\n'
echo "     ▶ 或： 直接新开一个终端窗口"
echo "  然后敲一次  grok --version  验证；看到开头的 🛡️  绿字就说明生效了。"
echo "  （在装之前就开着、又没重载的老终端里敲 grok 不会显示——这是最常见的『没显示』原因。）"
echo
echo "卸载： bash $SRC/uninstall.sh   （只移除哨兵，不动 grok 本身）"
