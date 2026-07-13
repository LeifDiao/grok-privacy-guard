# 🛡️ grok-privacy-guard

**中文 · [English](README.en.md)**

> 给 Grok CLI 加一层代码库隐私防护：防止你的代码库在不知情时被打包上传，并在**每次启动时检测上传状态、及时提醒你**。
> macOS · zsh / bash。所有脚本只读日志、只写你自己的 config，不外发任何数据。

## 能做什么

- **防止整仓上传**：阻止 grok 在后台把整个代码库（含 git 历史）打包上传，并一并拦下会话 trace 上传。
- **防止被绕过**：锁定 grok 自动更新 + 校验二进制指纹，二进制被替换会提醒。
- **启动检测**：每次启动 grok 自动自检——🟢 绿字＝防护生效、本次无上传；🔴 红字＝异常提醒。
- **历史检测**：一条命令检测你以前有没有代码库被上传过。

## 安装

### 方法 A · 自己装

```bash
git clone https://github.com/LeifDiao/grok-privacy-guard.git
cd grok-privacy-guard
bash install.sh
```

### 方法 B · 让 AI agent 帮你装

把这句话发给你的编码 agent（Claude Code / Cursor / …）：

> 读一下 https://github.com/LeifDiao/grok-privacy-guard ，帮我 clone 下来跑 `install.sh` 装好，并**保持哨兵每次启动都可见、不要开静默模式**。

`install.sh` 幂等、自带备份，agent 直接跑即可。

> ⚠️ **一定要让它"露脸"**：哨兵默认会在你每次启动 grok 前打印一行状态（🟢 防护生效 / 🔴 异常）。交给 agent 装时，务必要求它**保持这行可见、不要开启静默模式（`GROK_GUARD_QUIET`）**——你每次都能亲眼看到它在岗，才安心。别让它在后台"帮你装好就不吭声"。

> 装完新开终端自动生效；当前窗口先跑 `source ~/grok-privacy/grok-guard.sh`。

## 常用命令

| 命令 | 作用 |
|---|---|
| `bash install.sh` | 安装 / 更新 |
| `bash grok-guard-check.sh` | 起个假仓库**实测**防护是否真的生效（**升级 grok 后必跑**，会自动刷新指纹） |
| `bash grok-guard-evidence.sh` | 检测你历史上有没有代码库被上传过（只读） |
| `bash uninstall.sh` | 卸载哨兵（不动 grok，config 防护默认保留） |

## 每次启动会看到

```
🛡️  grok-guard: 上传防护生效 ✓  开关✓  指纹✓  —  启动 grok…
   … grok 正常运行 …
🛡️  grok-guard: 本次会话无整仓上传 · 队列干净 ✓
```

> grok 是**全屏 TUI**：启动前那行会**停留约 0.8 秒**让你看清，随后被全屏界面盖住；**退出 grok 后**再打印下面那行「本次会话…」。快命令（如 `grok --version`）不停顿。想关停顿：`export GROK_GUARD_HOLD=0`。

| 颜色 | 含义 |
|---|---|
| 🟢 绿 | 防护生效，本次无上传 |
| 🟡 黄 | 二进制被替换/刚升级 → 跑 `grok-guard-check.sh` 复检刷新 |
| 🔴 红 | 防护被改动（拦你确认）/ 本次疑似发生上传（提醒） |

临时绕过哨兵：`GROK_GUARD=0 grok ...`　·　只提醒不打绿字：`export GROK_GUARD_QUIET=1`

## 它改了什么 / 局限

- 往 `~/.grok/config.toml` 写三行（自动备份）：`disable_codebase_upload=true`、`trace_upload=false`、`auto_update=false`。
- **不做网络层拦截**，依赖 grok 遵守自己的开关——所以加了指纹校验 + 每次启动检测兜底。要物理拦截，用按进程防火墙（LuLu）或容器隔离。
- 你主动让 grok 读的文件仍会发给模型端（正常 AI 行为，不在防护范围）——别让它读敏感文件。

## 来源 / License

相关机制由 [@cereblab](https://gist.github.com/cereblab/dc9a40bc26120f4540e4e09b75ffb547) 的抓包分析记录（[HN 讨论](https://news.ycombinator.com/item?id=48877371)）。MIT License.
