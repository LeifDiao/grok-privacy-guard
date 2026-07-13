#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# grok-privacy-guard · 历史证据
# 从你自己机器的 grok 日志里，还原「过去哪些代码库被打包上传过、多少次、什么时候开着的」。
# 只读日志，不改任何东西。跑一下看看你自己中招没。
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
LOG="${GROK_HOME:-$HOME/.grok}/logs/unified.jsonl"
[ -f "$LOG" ] || { echo "没找到 grok 日志：$LOG（可能没用过或版本不同）"; exit 0; }

echo "══════════════════════════════════════════════"
echo " grok 历史上传证据（来自你本机日志，只读）"
echo "══════════════════════════════════════════════"
python3 - "$LOG" <<'PY'
import sys, json, collections
log=sys.argv[1]
sess_cwd={}; up_by_sess=collections.Counter()
starts=0; enq=0; fails=0
dec=[]  # (ts, uploads_enabled, source, reason)
for line in open(log, errors="ignore"):
    try: o=json.loads(line)
    except: continue
    sid=o.get("sid"); msg=o.get("msg",""); ctx=o.get("ctx",{}) or {}
    cwd=ctx.get("cwd") or ctx.get("working_directory") or ctx.get("repo_root")
    if cwd and sid: sess_cwd.setdefault(sid, cwd)
    if msg=="repo_state.upload.start": starts+=1; up_by_sess[sid]+=1
    elif msg=="repo_state.upload.enqueued": enq+=1
    elif "gcs_upload_failed" in msg or msg.startswith("upload failed"): fails+=1
    elif msg=="trace.upload.decision":
        dec.append((o.get("ts"), ctx.get("uploads_enabled"), ctx.get("trace_upload_source"), ctx.get("upload_reason")))

print(f"\n整仓上传发起(repo_state.upload.start)总次数: {starts}   入队: {enq}   失败: {fails}")
if starts==0:
    print("\n✅ 日志里没有整仓上传记录 —— 你这台大概率没被传过（或上传当时是关的）。")
else:
    print("\n📦 被打包上传过的工作目录（按上传发起次数）:")
    agg=collections.Counter()
    for sid,n in up_by_sess.items():
        agg[sess_cwd.get(sid, f"(未知目录 sid={str(sid)[:8]})")]+=n
    for cwd,n in agg.most_common():
        print(f"   [{n:>4} 次]  {cwd}")

if dec:
    # 找 uploads_enabled 的跳变，画出「开着的时间段」
    print("\n🕒 上传开关状态跳变（True=当时在传, source=remote 表示 xAI 服务端下发）:")
    prev=None
    for ts,en,src,reason in dec:
        if en!=prev:
            flag="🔴 开启" if en in (True,"True") else "🟢 关闭"
            print(f"   {ts}  {flag}  (source={src} reason={reason})")
            prev=en
    last=dec[-1]
    now="🔴 开启" if last[1] in (True,"True") else "🟢 关闭"
    print(f"\n   → 当前最新状态: {now} (source={last[2]})")
print()
PY
echo "说明：source=remote 代表这个开关是 xAI 服务器远程下发的（他们能随时改）。"
echo "装本工具并复检通过后，状态会变成 source=config（你本地说了算）。"
