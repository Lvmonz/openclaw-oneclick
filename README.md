# 🦞 OpenClaw 一键安装脚本 (Sidecar 进阶版)

一个脚本 + 一个 `.env` 文件，5 分钟完成 OpenClaw 大脑与肢体分离的生产级全自动化部署。

## ✨ 核心优势

- **极致稳定与彻底解耦**：将极其脆弱和消耗内存的 Headless Browser 从大脑容器中剥离，形成独立的 **Sidecar 双容器架构**。
- **永久锁死网页登录态**：浏览器配置文件 (Profile) 被单独硬挂载为独立数据卷 (`browser_profile`)。哪怕你每天重装、擦除大脑环境，推特/微信等所有网页的**登录状态永远不会掉**。
- **无损升级与重装体验**：执行 `./setup.sh --clean`，大脑可以实现干净重生，而肢体（社交账号登录态）毫发无损。
- **安装前 API 预检**：在拉取镜像前自动验证 API Key 连通性，避免装完才发现配错了。
- **动态容器编排**：不启用浏览器时只启动大脑容器，节省系统资源。
- 多供应商聚合支持（支持 10+ 平台：Anthropic / OpenAI / OpenRouter / DeepSeek / 硅基流动 / 智谱 / Kimi / Gemini / xAI / 本地大模型）
- 官方个人微信 ClawBot 插件扫码接入，Agent 已深度配置 `TOOLS.md`，支持直接将高清图片和文件打入微信对话框。
- **强制防死循环 Prompt**：增强版 `SOUL.md` 防线，当浏览器遇死爬虫（滑块、二维码验证）时，大模型主动中断重试并求援，彻底拒绝后台无脑 Token 消耗和微信消息轰炸。
- 采用业界标准 `browserless/chrome` 作为底层驱动，完美规避内网 CDP 端口被 127.0.0.1 隔离无法连接的坑，并内置自动软链 999 权限。

## 📦 文件说明

```
openclaw-oneclick/
├── setup.sh                    # 主交互式安装向导 (v2.0)
├── upgrade.sh                  # 一键升级脚本（版本感知）
├── repair.sh                   # 一键修复 / 诊断 / 日志导出
├── factory-reset.sh            # 一键洗脑 — 出厂重置脚本
├── .env.example                # 环境变量模板
├── docker-compose.yml          # 核心容器编排（大脑主容器）
├── docker-compose.browser.yml  # 浏览器 Sidecar 编排（按需加载）
├── .gitignore                  # 防止 .env 数据泄露
└── templates/                  #
    ├── SOUL.md                 # 被 setup.sh 动态加工的系统提示词底座
    ├── AGENTS.md               # 控制工作流模式
    └── MEMORY.md               # 长期记忆
```

## 🚀 快速开始

### 前置要求

- **满血版 (full)**：Docker Desktop（[下载地址](https://docker.com/get-started)）+ 至少 2GB 空闲内存
- **简易版 (lite)**：Node.js 22+（[下载地址](https://nodejs.org/)），无需 Docker

### 2 步安装

```bash
# 1. 克隆项目
git clone https://github.com/Lvmonz/openclaw-oneclick.git
cd openclaw-oneclick

# 2. 运行交互式安装向导（会先让你选择简易版/满血版）
chmod +x setup.sh upgrade.sh repair.sh
./setup.sh
```

> 💡 安装向导第一步会让你选择版本：⚡ **简易版** (无 Docker，本地环境) 或 🚀 **满血版** (Docker 容器化)。
> 💡 已有配置时再次运行会默认上次版本，可直接修改参数。

## 🏗️ 架构说明

```
宿主机                          Docker Compose 网络 (172.x.x.x)
─────────                       ──────────
.env (API Keys)    ──生成──> openclaw-core (大脑主容器)
                              │  ├── 独立挂载: openclaw-data (存放工作区与技能)
                              │
                              └── CHROME_CDP_URL=ws://openclaw-browser:9222
                                      │  (仅启用浏览器时)
                                      ▼
                             openclaw-browser (动作肢体容器, alpine-chrome)
                                 ├── 暴露 9222 供宿主机直接查验 debug
                                 └── 独立挂载: browser_profile (持久化保留 Twitter 等网站 Cookies)
```

- **安全网络隔离**：外部环境只暴露出给宿主机用的端口，容器相互之间通过纯内网的 WebSocket `.9222` 通信。
- **动态 SOUL 赋予**：安装脚本会根据你的选择，动态把当前 Sidecar 架构的使用说明写入 AI 的 `SOUL.md` 大脑皮层，AI 天生就知道如何运用 Playwright 连上它。
- **按需编排**：不启用浏览器时只运行 `docker-compose.yml`，启用浏览器时自动合并 `docker-compose.browser.yml`。

## 🔄 运维与更新

### 🧠 更换大模型 (LLM) 与重启 Agent

因为容器做了完善的数据挂载，**不需要重装**即可快速切换 Agent 的大脑：

**场景一：只想换模型（API 供应商或 URL 没变）**
比如你一开始选了深势 (DeepSeek)，想从 `deepseek-chat` 换成 `deepseek-reasoner`，直接用内部命令行秒切：
```bash
# 修改格式：供应商前缀/模型名，例如 deepseek/deepseek-reasoner
docker exec openclaw-main openclaw config set agents.defaults.model "deepseek/deepseek-reasoner"
# 让新模型热加载生效
docker exec openclaw-main openclaw gateway restart
```

**场景二：想换一个全新的 API 供应商 / 修改本地 API URL（推荐重跑向导）**
如果你想从 OpenAI 换到 Custom 代理，或者换个 API Key，最稳妥的方式是重新执行 `./setup.sh`（不带 `--clean` 参数）：
- 它会重新询问你的 API URL、Key 和模型名，并写死到大模型配置里。
- 因为没有加 `--clean`，它只会平滑刷新 `[1/7]` 的配置文件，**绝对不会**丢失你的微信登录态或浏览器配置库。
- *注：如果你手滑按了 `Ctrl+Z`，新版脚本内置了安全自毁机制，会自动强制清理底层进程防止环境死锁。*

### ⚙️ 日常运维

```bash
# 启动（不带浏览器）
docker compose up -d

# 启动（带浏览器 Sidecar）
docker compose -f docker-compose.yml -f docker-compose.browser.yml up -d

# 停止
docker compose down

# 查看核心日志
docker logs openclaw-main --tail 100 -f
```

### 🔄 一键升级

```bash
# 独立脚本（推荐）
bash upgrade.sh

# 或在安装向导确认页选择 "5" 一键升级
./setup.sh
```

升级会自动根据安装模式（lite/full）拉取最新镜像或 npm 包，保留所有数据和配置。

### 🔧 一键修复 / 诊断

```bash
# 独立脚本
bash repair.sh

# 或在安装向导确认页选择 "6" 一键修复
./setup.sh
```

修复工具会自动检测：文件完整性、Docker/Node 环境、容器健康、端口冲突、数据卷状态、磁盘空间等，并尝试自动修复。支持导出诊断日志（macOS 支持文件选择器）。

### 📱 多通讯频道

安装向导支持同时选择多个通讯频道：

| 频道 | 安装方式 | 需要配置 |
|------|----------|----------|
| 📱 微信 | `openclaw-weixin-cli` | 扫码授权 |
| 🔷 钉钉 | `openclaw channels add` | 企业应用 App ID/Secret |
| ✈️ Telegram | 内置频道 | Bot Token (@BotFather) |
| 🔵 飞书 | `@openclaw/feishu` 插件 | 企业应用 App ID/Secret |
| 🐧 QQ | `openclaw channels add` | Bot 应用凭证 |
| 🔧 自定义 | Webhook 配置 | URL + Token + 消息格式 |

### 🧹 一键洗脑 / 出厂重置

当 AI 出现幻觉、串记忆、行为异常，或者你调整了 `SOUL.md` / `SKILL.md` 后想让 AI 以全新状态重新开始时，使用出厂重置脚本：

```bash
# 普通重置：清空对话记忆、日志、LLM 缓存，保留浏览器登录态
bash factory-reset.sh

# 硬重置：额外清除浏览器 Cookie（需重新扫码登录各网站）
bash factory-reset.sh --hard
```

| 项目 | 普通重置 | 硬重置 (`--hard`) |
|------|:--------:|:-----------------:|
| 对话历史 | ✅ 清空 | ✅ 清空 |
| Agent 记忆 | ✅ 清空 | ✅ 清空 |
| LLM prompt cache | ✅ 清空 | ✅ 清空 |
| 日志 | ✅ 清空 | ✅ 清空 |
| 已安装的 Skills | ✅ **保留** | ✅ **保留** |
| 配置文件 (SOUL/IDENTITY/USER.md) | ✅ **保留** | ✅ **保留** |
| 微信账号绑定 | ✅ **保留** | ✅ **保留** |
| 浏览器 Cookie 与登录态 | ✅ **保留** | ❌ 清空 |

> 💡 **推荐**：日常调试用普通重置即可，无需每次都重新扫码。只有在浏览器状态异常（如网站检测到自动化、Cookie 过期）时再用 `--hard`。

### 彻底卸载

```bash
cd ~/openclaw-oneclick
docker compose down -v  # -v 意味着销毁包括登录态在内的一切卷数据
cd ~ && rm -rf ~/openclaw-oneclick
```

## ❓ 常见问题

**Q: 报错 `403 Author anthropic is banned` 怎么办？**
A: 这通常是因为 `openclaw.json` 中 API Key 的挂载方式不对。正确的配置应该使用 `models.providers` 显式配置，而非 `env` 层注入。解决方法：
1. 删除容器和数据：`docker compose down -v`
2. 重新运行：`./setup.sh --clean`
3. 如果仍然出现，进入容器检查配置：`docker exec openclaw-main cat /home/node/.openclaw/openclaw.json`，确认 API Key 在 `models.providers` 下而非 `env` 下。

**Q: 我发现 AI 用了一段时间浏览器后经常崩溃 (Connection Closed) 怎么办？**
A: 现代网页长时运行容易泄露。解决方式极简：`docker restart openclaw-browser`，重启仅需 1 秒，并且因为 `browser_profile` 挂载了的缘故，任何登录态都不会丢失。

**Q: 为什么 AI 不用内置的 browser 工具了？**
A: 之前用内置 browser 会把几十上百 MB 的 Chromium 强行塞进 `openclaw-core`，容易互相影响并导致内存无法回收。新架构用 python `playwright.chromium.connect_over_cdp("ws://openclaw-browser:9222")`，性能直接翻飞。

**Q: 安装时提示 API Key 验证失败？**
A: 安装向导会在拉取镜像前预检 API 连通性。如果提示失败：
1. 检查 API Key 是否正确复制（包括前缀 `sk-or-`、`sk-ant-` 等）
2. 检查网络是否可以访问对应的 API 地址
3. 确认账户余额是否充足（OpenRouter 需要先充值）

**Q: 不启用浏览器功能会有什么影响？**
A: AI 仍然可以通过 `fetch/curl` 获取网页文本内容（无 JS 渲染），但无法进行需要 JavaScript 的操作（如登录网页、操作 SPA 应用）。你可以之后随时重新运行 `./setup.sh` 启用。

## 📄 License

MIT
