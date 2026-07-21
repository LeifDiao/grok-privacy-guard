# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# grok-privacy-guard · 启动哨兵
# 在 ~/.zshrc 或 ~/.bashrc 里 source 本文件，把 `grok` 命令套一层核验：
#   · 启动前：查 config 禁用开关是否还在 + 二进制指纹有没有被换 → 打印状态条
#   · 退出后：查本次会话有没有触发整仓上传 / upload_queue 有没有被塞代码包
# 所有状态/告警都打到 stderr，不污染 grok 的 stdout（例如 --output-format json）。
# 临时绕过：  GROK_GUARD=0 grok ...
# 只报警不打绿字：  export GROK_GUARD_QUIET=1
# 关掉启动前停顿：  export GROK_GUARD_HOLD=0
# 项目主页：https://github.com/lemomo-ai/grok-privacy-guard
# ─────────────────────────────────────────────────────────────────────────────
# 定义函数前先解析真正的 grok 可执行文件——即使 grok 不在 ~/.grok/bin（比如 npm 装的），
# 也能正常显示哨兵，而不是静默放行。
unset -f grok 2>/dev/null || true
if [ -x "$HOME/.grok/bin/grok" ]; then
  _GROK_GUARD_BIN="$HOME/.grok/bin/grok"
else
  _GROK_GUARD_BIN="$(command -v grok 2>/dev/null || true)"
fi

grok() {
  local BIN="${_GROK_GUARD_BIN:-$HOME/.grok/bin/grok}"
  local CFG="$HOME/.grok/config.toml"
  local QUEUE="$HOME/.grok/upload_queue"
  local LOG="$HOME/.grok/logs/unified.jsonl"
  local DIR="${GROK_PRIVACY_DIR:-$HOME/grok-privacy}"
  local PIN="$DIR/known-good.sha256"
  local G=$'\033[32m' R=$'\033[31m' Y=$'\033[33m' D=$'\033[2m' N=$'\033[0m'
  local quiet="${GROK_GUARD_QUIET:-0}"
  local ans base rc cur good staged

  # grok 没装好就直接透传，绝不卡住 shell
  [ -x "$BIN" ] || { command grok "$@"; return $?; }
  if [ "${GROK_GUARD:-1}" = 0 ]; then
    printf '%s🛡️  grok-guard: 已用 GROK_GUARD=0 绕过%s\n' "$D" "$N" >&2; "$BIN" "$@"; return $?
  fi

  # ① 配置开关
  local block=0 miss=""
  grep -qE '^[[:space:]]*disable_codebase_upload[[:space:]]*=[[:space:]]*true' "$CFG" 2>/dev/null \
    || { miss="disable_codebase_upload"; block=1; }
  grep -qE '^[[:space:]]*trace_upload[[:space:]]*=[[:space:]]*false' "$CFG" 2>/dev/null \
    || { miss="$miss trace_upload"; block=1; }

  # ② 二进制指纹（shasum 跟随符号链接，直接哈希目标文件）
  local fp="ok"
  cur="$(shasum -a 256 "$BIN" 2>/dev/null | awk '{print $1}')"
  if [ -f "$PIN" ]; then
    good="$(cat "$PIN" 2>/dev/null)"
    [ -n "$good" ] && [ "$cur" != "$good" ] && fp="changed"
  else
    fp="unpinned"
  fi

  # 是否"快命令"（输出直接打到终端、横幅本来就看得见）——这些不加停顿
  local hold=1 shown=0 _a
  for _a in "$@"; do case "$_a" in -p|--single|--version|-v|--help|-h) hold=0; break;; esac; done

  # —— 启动前状态条（一律 stderr）——
  if [ "$block" = 1 ]; then
    printf '%s🛡️  grok-guard: ✗ 上传防护开关异常（缺:%s）— grok 可能会上传你的代码库！%s\n' "$R" "$miss" "$N" >&2
    printf '仍要启动 grok 吗？[y/N] ' >&2; read -r ans
    case "$ans" in [yY]*) ;; *) printf '已取消。修复: bash %s/grok-guard-check.sh\n' "$DIR" >&2; return 1;; esac
  elif [ "$fp" = changed ]; then
    printf '%s🛡️  grok-guard: 开关✓  指纹⚠变了%s（若刚升级属正常 → bash %s/grok-guard-check.sh 复检刷新）\n' "$Y" "$N" "$DIR" >&2; shown=1
  elif [ "$fp" = unpinned ]; then
    printf '%s🛡️  grok-guard: 开关✓  指纹?未固定%s（先跑一次 bash %s/grok-guard-check.sh）\n' "$Y" "$N" "$DIR" >&2; shown=1
  elif [ "$quiet" != 1 ]; then
    printf '%s🛡️  grok-guard: 上传防护生效 ✓  开关✓  指纹✓  —  启动 grok…%s\n' "$G" "$N" >&2; shown=1
  fi
  # grok 是全屏 TUI，会瞬间盖住上面这行——停顿一下让你看得见（快命令不停顿；GROK_GUARD_HOLD=0 可关）
  [ "$shown" = 1 ] && [ "$hold" = 1 ] && sleep "${GROK_GUARD_HOLD:-0.8}" 2>/dev/null

  # —— 跑真 grok（stdout/stderr 原样透传，哨兵不掺和）——
  base="$(wc -l < "$LOG" 2>/dev/null || echo 0)"
  "$BIN" "$@"; rc=$?

  # —— 退出后核查（一律 stderr）——
  local hit=0
  if tail -n +$((base+1)) "$LOG" 2>/dev/null | grep -q 'repo_state.upload.start'; then
    printf '%s🚨 grok-guard: 本次会话触发了 repo_state.upload.start —— 疑似整仓上传！核实: bash %s/grok-guard-check.sh%s\n' "$R" "$DIR" "$N" >&2; hit=1
  fi
  staged="$(find "$QUEUE" -mindepth 1 ! -path '*/scratch' -type f 2>/dev/null)"
  [ -n "$staged" ] && { printf '%s🚨 grok-guard: upload_queue 出现暂存文件: %s%s\n' "$R" "$staged" "$N" >&2; hit=1; }
  [ "$hit" = 0 ] && [ "$quiet" != 1 ] && printf '%s🛡️  grok-guard: 本次会话无整仓上传 · 队列干净 ✓%s\n' "$G" "$N" >&2
  return $rc
}
