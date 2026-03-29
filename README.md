# 🦞 OpenClaw 一键安装脚本 (Sidecar 进阶版)

一个脚本 + 一个 `.env` 文件，5 分钟完成 OpenClaw 大脑与肢体分离的生产级全自动化部署。

## ✨ 核心优势

- **极致稳定与彻底解耦**：将极其脆弱和消耗内存的 Headless Browser 从大脑容器中剥离，形成独立的 **Sidecar 双容器架构**。
- **永久锁死网页登录态**：浏览器配置文件 (Profile) 被单独硬挂载为独立数据卷 (`browser_profile`)。哪怕你每天重装、擦除大脑环境，推特/微信等所有网页的**登录状态永远不会掉**。
- **无损升级与重装体验**：执行 `./setup.sh --clean`，大脑可以实现干净重生，而肢体（社交账号登录态）毫发无损。
- **安装前 API 预检**：在拉取镜像前自动验证 API Key 连通性，避免装完才发现配错了。
- **动态容器编排**：不启用浏览器时只启动大脑容器，节省系统资源。
- 多供应商聚合支持（Anthropic / OpenAI / OpenRouter / DeepSeek / 硅基流动 / Kimi / 自定义代理）
- 官方个人微信 ClawBot 插件扫码接入

## 📦 文件说明

```
openclaw-oneclick/
├── setup.sh                    # 主交互式安装向导
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

- Docker Desktop（[下载地址](https://docker.com/get-started)）
- 至少预留 **2GB 空闲内存** 给 Sidecar 浏览器容器（仅在启用浏览器功能时需要）

### 2 步安装

```bash
# 1. 克隆项目
git clone https://github.com/Lvmonz/openclaw-oneclick.git
cd openclaw-oneclick

# 2. 运行交互式安装向导
chmod +x setup.sh
./setup.sh
```

> 💡 无需手动编辑 `.env`——向导会带你走完所有配置流程。
> 💡 **重装说明**：普通的 `./setup.sh` 会保留所有数据和插件；`./setup.sh --clean` 会清空核心数据，但会**询问你是否保留浏览器的登录态**。

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

### 日常运维

```bash
# 启动（不带浏览器）
docker compose up -d

# 启动（带浏览器 Sidecar）
docker compose -f docker-compose.yml -f docker-compose.browser.yml up -d

# 停止
docker compose down

# 神级操作：实时围观 AI 视角的网页动作
# 在本地浏览器打开: http://127.0.0.1:9222 然后点击 target 即可看到实时回放！

# 升级到官方最新版镜像并拉起
docker compose pull && docker compose up -d

# 查看核心日志
docker logs openclaw-main --tail 100 -f
```

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
