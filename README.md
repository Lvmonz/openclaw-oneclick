# 🦞 OpenClaw 一键安装脚本

一个脚本 + 一个 `.env` 文件，5 分钟完成 OpenClaw 的完整部署。

## ✨ 一键搞定

- Docker 沙盒环境（类 conda 隔离，每个容器独立工作目录）
- New-api + Anthropic Claude 模型配置
- 双模型路由 + Prompt 缓存优化
- 高执行力助理提示词模板（Soul / User / Agents）
- 5 个核心 Skills 自动安装
- 个人微信（官方 ClawBot 插件扫码接入）
- 本地 Chrome Cookies 共享（可选，让 AI 访问已登录网站）
- 每次安装自动清空旧数据（干净重装）

## 📦 文件说明

```
openclaw-oneclick/
├── setup.sh              # 主安装脚本（自动 7 步）
├── .env.example          # 环境变量模板
├── docker-compose.yml    # Docker 编排（命名卷 + Chrome 挂载）
├── .gitignore            # 防止 .env 和数据泄露
└── templates/            # MD 文件模板
    ├── SOUL.md           # AI 人格定义（执行力优先）
    ├── AGENTS.md         # 权限控制（自动执行大部分操作）
    └── MEMORY.md         # 记忆初始化
```

## 🚀 快速开始

### 前置要求

- Docker Desktop（[下载地址](https://docker.com/get-started)）
- 模型 API Key（推荐通过 [New-api](https://github.com/Calcium-Ion/new-api) 管理）

### 2 步安装

```bash
# 1. 克隆项目
git clone https://github.com/Lvmonz/openclaw-oneclick.git
cd openclaw-oneclick

# 2. 运行交互式安装向导
chmod +x setup.sh
./setup.sh
```

> 💡 无需手动编辑 `.env`——脚本会一步步引导你填写 API Key、选择模型、配置微信等。

> 💡 **重装说明**：每次运行 `./setup.sh` 会自动清空旧的容器数据（配置/缓存/对话记录），`.env` 中的 API Key 等参数不受影响。

### 预期输出

```
🦞 OpenClaw 一键安装向导
========================
✔ Step 1: 清空旧数据并准备配置文件...
✔ Step 2: 拉取镜像并启动容器...
✔ Step 3: 注入配置文件...
✔ Step 4: 安装核心 Skills...
✔ Step 5: 配置微信插件...
✔ Step 6: 清理临时文件...
✔ Step 7: 重启容器...

✅ 安装完成！

CLI 对话:  docker exec -it openclaw-main openclaw agent -m "你的问题"
查看日志:  docker compose logs -f
```

## ⚙️ 交互式配置项

安装向导会依次引导你完成 5 步配置：

| Step | 内容 | 说明 |
|------|------|------|
| 1 | 模型供应商 | New-api Base URL + API Key（必填，自动校验格式）|
| 2 | 模型选择 | 3 种预置组合可选，也支持自定义 |
| 3 | 微信接入 | 官方 ClawBot 插件，安装后扫码授权（可选）|
| 3 | Chrome 共享 | 挂载本地 Chrome Cookies，让 AI 访问已登录网站（可选，只读）|
| 3 | 联网搜索 | Brave Search API，免费 2000 次/月（可选）|
| 4 | 用户信息 | 名字、语言、时区（用于生成 User.md）|
| 5 | 确认总览 | 可跳回任意步骤修改，Ctrl+C 随时退出 |

## 🏗️ 架构说明

```
宿主机                          Docker 容器
─────────                       ──────────
.env (API Keys)    ──docker cp──> /home/node/.openclaw/openclaw.json
templates/*.md     ──docker cp──> /home/node/.openclaw/workspace/*.md
Chrome 用户数据    ──volume:ro──> /home/node/.chrome-host/
                                  
Docker Volume: openclaw-data ──> /home/node/.openclaw/
                                  ├── workspace/  (AI 独立工作目录)
                                  ├── skills/     (技能包)
                                  └── extensions/ (插件)
```

- **配置注入**：`setup.sh` 写临时文件 → 启动容器 → `docker cp` 注入 → 重启生效
- **SOUL.md 动态生成**：根据用户配置（如 Chrome 共享是否开启）动态注入运行环境信息，让 AI 知道自己在 Docker 中运行、能访问哪些资源
- **数据隔离**：每个容器有独立的 Docker 命名卷，互不干扰
- **清空重装**：`./setup.sh` 自动删除旧卷，从零开始

## 🔄 更新脚本

```bash
cd ~/openclaw-oneclick

# 拉取最新脚本
git pull

# 重新安装（自动清空旧数据）
./setup.sh
```

## 📋 日常操作

```bash
# 启动
docker compose up -d

# 停止（数据保留）
docker compose down

# 升级到最新版
docker compose pull && docker compose up -d

# 进入容器
docker exec -it openclaw-main bash

# 查看日志
docker logs openclaw-main --tail 50
```

## 🗑️ 彻底卸载

```bash
cd ~/openclaw-oneclick
docker compose down -v
docker rmi ghcr.io/openclaw/openclaw:latest
cd ~ && rm -rf ~/openclaw-oneclick
docker system prune -f   # 可选
```

## ❓ 常见问题

**Q: 如何与 OpenClaw 对话？**
A: 微信扫码授权后直接微信聊天，或者用 CLI：`docker exec -it openclaw-main openclaw agent -m "你的问题"`

**Q: `/status` 显示 Provider 为空**
A: 检查 `.env` 中 `NEWAPI_BASE_URL` 末尾是否有 `/v1`。

**Q: 重装后数据还在？**
A: 不会。每次 `./setup.sh` 会自动销毁旧的 Docker 命名卷，完全从零开始。`.env` 中的配置参数不受影响。

**Q: Chrome Cookies 共享安全吗？**
A: 以只读模式挂载，AI 无法修改。但 AI 可以读取你所有网站的登录凭证，请知悉风险后启用。

## 📖 完整教程

配套详细教程请关注公众号，回复「**教程**」获取。

## 📄 License

MIT
