# 🛡️ grok-privacy-guard

**中文 · [English](README.en.md)**

> 关掉 xAI 官方 Grok CLI「偷偷把你整个代码库打包上传到云端」的行为，并在**每次启动 grok 时用一行字告诉你有没有在传**。
> macOS · zsh / bash。所有脚本只读日志、只写你自己的 config，不外发任何数据。

## 能做什么

- **本地关死整仓上传**：禁掉 grok 把整个代码库（含 git 历史）打包上传的旁路通道，以及会话 trace 上传。
- **防止被绕过**：锁死 grok 自动更新 + 校验二进制指纹，二进制被换会告警。
- **每次启动可见**：你敲 `grok`，🟢 绿字表示"上传已关、本次没偷传"；🔴 红字报警。
- **查历史**：一条命令还原你以前被打包上传过哪些代码库。

## 安装

### 方法 A · 自己装

```bash
git clone https://github.com/LeifDiao/grok-privacy-guard.git
cd grok-privacy-guard
bash install.sh
```

### 方法 B · 让 AI agent 帮你装

把这句话发给你的编码 agent（Claude Code / Cursor / …）：

> 读一下 https://github.com/LeifDiao/grok-privacy-guard ，帮我 clone 下来跑 `install.sh` 装好。

`install.sh` 幂等、自带备份，agent 直接跑即可。

> 装完新开终端自动生效；当前窗口先跑 `source ~/grok-privacy/grok-guard.sh`。

## 常用命令

| 命令 | 作用 |
|---|---|
| `bash install.sh` | 安装 / 更新 |
| `bash grok-guard-check.sh` | 起个假仓库**实测**上传是否真被禁用（**升级 grok 后必跑**，会自动刷新指纹） |
| `bash grok-guard-evidence.sh` | 查你历史上被上传过哪些代码库（只读） |
| `bash uninstall.sh` | 卸载哨兵（不动 grok，config 开关默认保留） |

## 每次启动会看到

```
🛡️  grok-guard: 上传禁用生效 ✓  开关✓  指纹✓  —  启动 grok…
   … grok 正常运行 …
🛡️  grok-guard: 本次会话无整仓上传 · 队列干净 ✓
```

| 颜色 | 含义 |
|---|---|
| 🟢 绿 | 上传禁用生效，本次没偷传 |
| 🟡 黄 | 二进制被换/刚升级 → 跑 `grok-guard-check.sh` 复检刷新 |
| 🔴 红 | 开关被动过（拦你确认）/ 本次疑似触发上传（报警） |

临时绕过哨兵：`GROK_GUARD=0 grok ...`　·　只报警不打绿字：`export GROK_GUARD_QUIET=1`

## 它改了什么 / 局限

- 往 `~/.grok/config.toml` 写三行（自动备份）：`disable_codebase_upload=true`、`trace_upload=false`、`auto_update=false`。
- **不做网络层拦截**，依赖 grok 遵守自己的开关——所以加了指纹锁 + 每次自检兜底。要物理拦截，用按进程防火墙（LuLu）或容器隔离。
- 你主动让 grok 读的文件仍会发给模型端（正常 AI 行为，不在本开关范围）——别让它读敏感文件。

## 来源 / License

机制由 [@cereblab](https://gist.github.com/cereblab/dc9a40bc26120f4540e4e09b75ffb547) 的抓包分析揭示（[HN 讨论](https://news.ycombinator.com/item?id=48877371)）。MIT License.
