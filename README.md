# 🛡️ grok-privacy-guard

> 一条命令，关掉 xAI 官方 Grok CLI「偷偷把你整个代码库打包上传」的行为，并且**每次启动都当着你的面自检一遍**。
>
> **TL;DR (EN):** One command to disable xAI Grok CLI's silent whole-repo upload, pin the binary, and verify on every launch. macOS / zsh + bash.

---

## 30 秒看懂 · 怎么用

- **它解决什么**：Grok CLI 会在你不知情时，把**整个代码库**打包传到 xAI 云端。本工具把这个上传**在你本地关死**，并在**每次你敲 `grok` 时用一行字告诉你「没在偷传」**。
- **三步用起来**：
  1. `bash grok-guard-evidence.sh` —— 先看你以前被传过没
  2. `bash install.sh` —— 一键关闭上传 + 装好哨兵
  3. 以后照常用 `grok`：看到 🟢 绿字就安心，🔴 红字就警惕
- **不放心开关有没有真生效？** `bash grok-guard-check.sh` 会起个假仓库真跑一轮，实测到底还传不传。

---

## 背景：发生了什么

安全研究者 **cereblab** 对官方 Grok CLI（`~/.grok`）做了线级抓包分析，发现它在 `uploads_enabled=true` 期间，会通过一条**独立于模型对话的旁路通道**，把**整个工作目录（含 git 历史）**打包上传到 xAI 的 Google Cloud 存储桶 `grok-code-session-traces`——**和模型有没有读你的文件无关**。曝光后，xAI 在 2026-07-12 深夜通过**服务端远程开关**把它悄悄关掉了。

- 抓包分析：https://gist.github.com/cereblab/dc9a40bc26120f4540e4e09b75ffb547
- Hacker News 讨论：https://news.ycombinator.com/item?id=48877371

问题的核心不是"AI 读文件"，而是：**这条上传通道默认开启、不在文档里明示、由 xAI 服务端远程控制，你随时可能在不知情下被重新打开。**

## 第一步：先看你自己中招没（只读，不改任何东西）

```bash
bash grok-guard-evidence.sh
```

它会从你**本机 grok 日志**里还原历史。真实一台机器的输出长这样👇

```
整仓上传发起(repo_state.upload.start)总次数: 189   入队: 118   失败: 2

📦 被打包上传过的工作目录（按上传发起次数）:
   [  84 次]  .../my-web-app
   [  61 次]  .../my-notes
   [  29 次]  .../my-desktop-app
   ...
🕒 上传开关状态跳变:
   2026-07-09  🔴 开启 (source=remote reason=proxy)     ← xAI 服务端下发，在传
   2026-07-12T23:53  🟢 关闭 (source=remote)            ← 曝光后 xAI 远程关闭
   → 当前最新状态: 🟢 关闭 (source=config)               ← 装了本工具后，你本地说了算
```

`source=remote` = 开关攥在 xAI 手里；`source=config` = 攥在你手里。**这就是本工具做的事。**

## 对比

| | Grok CLI 默认 | 装了 grok-privacy-guard |
|---|---|---|
| 整仓上传 | 由 xAI 服务端远程开关控制（`source=remote`） | 本地写死禁用（`source=config`），xAI 改不动 |
| 二进制 | 自动更新，可能被静默替换 | 锁定 + 指纹校验，换了会告警 |
| 你怎么知道它此刻在不在传 | 不知道，得逆向抓包 | **每次启动一行绿字告诉你**，出事红字报警 |
| 历史影响 | 无从查证 | `evidence` 脚本一键还原 |

## 它做了什么（三件事）

1. **本地写死两个禁用开关**到 `~/.grok/config.toml`：
   ```toml
   [harness]
   disable_codebase_upload = true   # 关掉整仓 before/after_codebase.tar.gz 上传
   [telemetry]
   trace_upload = false             # 关掉会话 trace / session_state 上传
   ```
2. **锁死自动更新**（`[cli] auto_update = false`）+ 固定二进制 SHA-256 指纹，防止 xAI 推新二进制绕过开关。
3. **装启动哨兵**：把 `grok` 命令包一层，每次启动前后自检。

## 安装

```bash
git clone https://github.com/LeifDiao/grok-privacy-guard.git
cd grok-privacy-guard
bash install.sh          # 幂等；会自动备份你的 config.toml
```

安装器会：写入禁用开关（保留你其它配置）→ 关自动更新 → 固定指纹 → 注入 `~/.zshrc`/`~/.bashrc` → 跑一次完整复检。

> 当前已开着的终端窗口：`source ~/grok-privacy/grok-guard.sh` 立即生效；新开终端自动生效。

## 每次启动你会看到什么

```
🛡️  grok-guard: 上传禁用生效 ✓  开关✓  指纹✓  —  启动 grok…
   … grok 正常运行 …
🛡️  grok-guard: 本次会话无整仓上传 · 队列干净 ✓
```

| 颜色 | 含义 |
|---|---|
| 🟢 绿 | 一切正常，上传禁用生效，本次没偷传 |
| 🟡 黄 `指纹⚠变了` | 二进制被换/你刚升级 → 跑 `grok-guard-check.sh` 复检刷新 |
| 🔴 红 | 开关被动过（会拦你确认）/ 本次会话疑似触发了上传（报警） |

- 临时绕过哨兵：`GROK_GUARD=0 grok ...`
- 只报警不打绿字：`export GROK_GUARD_QUIET=1`

## 升级 grok 之后

因为关了自动更新，升级都由你手动触发。升级后**务必**跑一次：

```bash
bash ~/grok-privacy/grok-guard-check.sh
```

它会起一个装假数据的隔离仓库**实跑一轮**，确认上传仍是关的（`uploads_enabled=False`），并**自动刷新指纹**——之后哨兵就不再告警。这一步的关键是它**不看配置写了啥，只看实际跑起来传不传**。

## 更严格（可选，按需加码）

配置法本质是"信任二进制会遵守自己的开关"。要更硬：

| 档 | 做法 | 强度 |
|---|---|---|
| **本工具** | 本地写死 + 锁二进制 + 每次自检 | 自律 + 可核查 |
| Tier 3 | 按进程出网防火墙（LuLu/Little Snitch）：只放行 grok 访问你的模型端点，其余 deny | 物理拦截网络 |
| Tier 4 | 把 grok 跑在容器/VM 里，只挂当前仓库、出网锁模型端点 | 结构性隔离 |
| 终极 | `grok logout` + 卸载 | 100% |

## 卸载

```bash
bash uninstall.sh   # 只移除哨兵与注入行，不动 grok；config 里的禁用开关默认保留
```

## 局限性（说实话）

- 本工具**不做网络层拦截**，它依赖 grok 二进制遵守自己的 `disable_codebase_upload` 开关——所以才配了指纹锁 + 每次自检兜底。要物理拦截请上 Tier 3/4。
- 模型对话通道（你主动让它读的文件会发给模型端）属正常 AI 行为，不在本开关范围——**别让 grok 去读放着敏感内容的文件**。
- 目前面向 macOS + zsh/bash，路径按官方 `~/.grok` 布局。其它平台欢迎 PR。

## 工作原理

Grok CLI 每轮开始会打一条 `trace.upload.decision` 日志，字段 `uploads_enabled` / `trace_upload_source` 决定传不传、听谁的。本工具把 `source` 从 `remote` 变成 `config`，并用 `repo_state.upload.start` 事件 + `~/.grok/upload_queue` 暂存目录作为"是否真的传了"的硬证据来源。全部脚本只读日志/写你自己的 config，无任何外发。

## 致谢

- [@cereblab](https://gist.github.com/cereblab) 的线级抓包分析首先揭示了这个机制。

## License

MIT
