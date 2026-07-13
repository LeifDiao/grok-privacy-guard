#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# grok-privacy-guard · 完整复检
# 不信任 xAI 的说法，直接看硬指标：
#   ① config.toml 里禁用开关还在   ② 起隔离假仓库实跑一轮，看上传决策是不是关的
#   ③ upload_queue 没被塞代码包    并在通过后刷新「已知良好指纹」
# 用法： bash grok-guard-check.sh          （默认：实跑一次隔离测试，最可靠）
#        bash grok-guard-check.sh --quick  （只查配置+最近一次日志，不起 grok）
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

GROK_HOME="${GROK_HOME:-$HOME/.grok}"
CONFIG="$GROK_HOME/config.toml"
LOG="$GROK_HOME/logs/unified.jsonl"
QUEUE="$GROK_HOME/upload_queue"
GROKBIN="$GROK_HOME/bin/grok"
DIR="${GROK_PRIVACY_DIR:-$HOME/grok-privacy}"
PIN="$DIR/known-good.sha256"
MODE="${1:-}"
FAIL=0
c(){ printf "\033[%sm%s\033[0m" "$1" "$2"; }
ok(){ echo "  $(c 32 '✓') $1"; }
bad(){ echo "  $(c 31 '✗') $1"; FAIL=1; }
warn(){ echo "  $(c 33 '!') $1"; }

echo "══════════════════════════════════════════════"
echo " grok 上传禁用 · 复检   $(date '+%Y-%m-%d %H:%M')"
echo "══════════════════════════════════════════════"
if [ -x "$GROKBIN" ]; then echo " 版本: $("$GROKBIN" --version 2>/dev/null)"; else warn "找不到 grok 可执行文件 ($GROKBIN)"; fi
echo

echo "① 配置开关（config.toml）"
grep -qE '^[[:space:]]*disable_codebase_upload[[:space:]]*=[[:space:]]*true' "$CONFIG" 2>/dev/null && ok "harness.disable_codebase_upload = true" || bad "缺 harness.disable_codebase_upload=true"
grep -qE '^[[:space:]]*trace_upload[[:space:]]*=[[:space:]]*false'           "$CONFIG" 2>/dev/null && ok "telemetry.trace_upload = false"         || bad "缺 telemetry.trace_upload=false"
grep -qE '^[[:space:]]*auto_update[[:space:]]*=[[:space:]]*false'            "$CONFIG" 2>/dev/null && ok "cli.auto_update = false（二进制不会被静默替换）" || warn "auto_update 未关，升级可能被静默推送"
echo

if [ "$MODE" != "--quick" ] && [ -x "$GROKBIN" ]; then
  echo "② 隔离实测（起一个假仓库跑一轮）"
  TDIR="$(mktemp -d)"; trap 'rm -rf "$TDIR"' EXIT
  printf 'CANARY-CHECK-NEVERREAD do not read\n' > "$TDIR/never_read.txt"
  printf 'FAKE_KEY=CANARY-FAKE-should-not-leave\n' > "$TDIR/.env"
  ( cd "$TDIR" && git init -q && git add -A && git -c user.email=a@a -c user.name=a commit -qm x ) 2>/dev/null
  BASE=$(wc -l < "$LOG" 2>/dev/null || echo 0)
  ( cd "$TDIR" && "$GROKBIN" -p "Reply with exactly: OK" --cwd "$TDIR" --permission-mode bypassPermissions --output-format plain </dev/null ) >/dev/null 2>&1
  NEW="$(tail -n +$((BASE+1)) "$LOG" 2>/dev/null)"
  DEC="$(printf '%s\n' "$NEW" | python3 -c '
import sys,json
last=None
for l in sys.stdin:
    try:o=json.loads(l)
    except:continue
    if o.get("msg")=="trace.upload.decision": last=o.get("ctx",{})
if last: print(last.get("uploads_enabled"), last.get("trace_upload_source"), last.get("upload_reason"))
' 2>/dev/null)"
  read -r UPEN SRC REASON <<< "$DEC"
  if [ "$UPEN" = "True" ]; then
    bad "上传决策 uploads_enabled=True (source=$SRC reason=$REASON) —— 上传处于开启！"
  elif [ "$UPEN" = "False" ]; then
    ok "上传决策 uploads_enabled=False (source=$SRC reason=$REASON)"
    [ "$SRC" = "config" ] && ok "决策来源=config（你本地说了算，不看 xAI 服务端脸色）" || warn "决策来源=$SRC（多为遥测已关，非本地配置驱动）"
  else
    warn "没拿到上传决策（grok 可能未登录/离线，本次跳过实测，靠①③判定）"
  fi
  if printf '%s\n' "$NEW" | grep -q 'repo_state.upload.start'; then bad "出现 repo_state.upload.start —— 整仓上传被触发！"; else ok "无 repo_state.upload.start"; fi
  if printf '%s\n' "$NEW" | grep -q 'CANARY-CHECK-NEVERREAD'; then bad "假 canary 进了上传管线！"; else ok "假数据未进上传管线"; fi
else
  echo "② 最近一次上传决策（--quick，不起 grok）"
  DEC="$(grep -F 'trace.upload.decision' "$LOG" 2>/dev/null | tail -1 | python3 -c '
import sys,json
for l in sys.stdin:
    try:
        o=json.loads(l);c=o.get("ctx",{});print(c.get("uploads_enabled"),c.get("trace_upload_source"),c.get("upload_reason"))
    except:pass' 2>/dev/null)"
  read -r UPEN SRC REASON <<< "$DEC"
  if [ "$UPEN" = "True" ]; then bad "最近决策 uploads_enabled=True —— 上传处于开启！"
  elif [ "$UPEN" = "False" ]; then ok "最近决策 uploads_enabled=False (source=$SRC)"
  else warn "日志里暂无决策记录，建议去掉 --quick 实测一次"; fi
fi
echo

echo "③ upload_queue（有没有暂存待传的代码包）"
STAGED="$(find "$QUEUE" -mindepth 1 ! -path '*/scratch' -type f 2>/dev/null)"
if [ -z "$STAGED" ]; then ok "队列干净，无待传代码包"; else bad "队列里有暂存文件："; printf '      %s\n' "$STAGED"; fi
echo

# 通过则刷新「已知良好指纹」，供哨兵比对
if [ "$FAIL" = 0 ] && [ -x "$GROKBIN" ]; then
  mkdir -p "$DIR"
  shasum -a 256 "$GROKBIN" 2>/dev/null | awk '{print $1}' > "$PIN"
  echo "  $(c 32 '✓') 已刷新二进制指纹 -> $PIN"; echo
fi

echo "══════════════════════════════════════════════"
if [ "$FAIL" = 0 ]; then echo " 结论: $(c 32 '通过 ✅  上传仍被禁用')"; else echo " 结论: $(c 31 '⚠️ 有异常，见上面的 ✗，考虑卸载或加装防火墙/容器隔离')"; fi
echo "══════════════════════════════════════════════"
exit $FAIL
