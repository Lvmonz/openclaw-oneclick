# 🦞 OpenClaw 一键安装脚本

一个脚本 + 一个 `.env` 文件，5 分钟完成 OpenClaw 的完整部署。

## ✨ 一键搞定

- Docker 沙盒环境（类 conda 隔离，每个容器独立工作目录）
- 多供应商支持（Anthropic / OpenAI / DeepSeek / 硅基流动 / OpenRouter / Kimi / 自定义代理）
- 双模型路由（Primary + Thinking 自动切换）
- 高执行力助理提示词模板（Soul / User / Agents）
- 5 个核心 Skills 自动安装
- 容器内 Chromium 浏览器（可选，AI 直接浏览网页）
- 个人微信（官方 ClawBot 插件扫码接入）

## 📦 文件说明

```
openclaw-oneclick/
├── setup.sh              # 主安装脚本（交互式 7 步）
├── .env.example          # 环境变量模板
├── docker-compose.yml    # Docker 编排（命名卷隔离）
├── .gitignore            # 防止 .env 和数据泄露
└── templates/            # MD 文件模板
    ├── SOUL.md           # AI 人格定义（执行力优先 + 环境感知）
    ├── AGENTS.md         # 权限控制（自动执行大部分操作）
    └── MEMORY.md         # 记忆初始化
```

## 🚀 快速开始

### 前置要求

- Docker Desktop（[下载地址](https://docker.com/get-started)）
- 模型 API Key（支持多种供应商，安装时选择）

### 2 步安装

```bash
# 1. 克隆项目
git clone https://github.com/Lvmonz/openclaw-oneclick.git
cd openclaw-oneclick

# 2. 运行交互式安装向导
chmod +x setup.sh
./setup.sh
```

> 💡 无需手动编辑 `.env`——脚本会一步步引导你选择供应商、填写 API Key、选择模型、配置微信等。

> 💡 **重装说明**：普通 `./setup.sh` 保留已安装的插件和 Skills；`./setup.sh --clean` 彻底清空重装。

## ⚙️ 交互式配置项

安装向导会依次引导你完成 5 步配置：

| Step | 内容 | 说明 |
|------|------|------|
| 1 | 模型供应商 | 7 种预置供应商可选（Anthropic/OpenAI/DeepSeek/硅基流动/OpenRouter/Kimi），也支持自定义代理 |
| 2 | 模型选择 | 每个供应商有推荐组合，也支持自定义 |
| 3 | 可选功能 | 微信接入、浏览器（容器内 Chromium）、联网搜索 |
| 4 | 用户信息 | 名字、语言、时区（用于生成 User.md）|
| 5 | 确认总览 | 可跳回任意步骤修改，Ctrl+C 随时退出 |

## 🏗️ 架构说明

```
宿主机                          Docker 容器
─────────                       ──────────
.env (API Keys)    ──docker cp──> /home/node/.openclaw/openclaw.json
templates/*.md     ──docker cp──> /home/node/.openclaw/workspace/*.md

                                  容器内 Chromium（可选）
                                  └── OpenClaw browser 工具直接调用

 Docker Volume: openclaw-data ──> /home/node/.openclaw/
                                  ├── workspace/  (AI 独立工作目录)
                                  ├── skills/     (技能包)
                                  └── extensions/ (插件)
```

- **配置注入**：`setup.sh` 写临时文件 → 启动容器 → `docker cp` 注入 → 重启生效
- **SOUL.md 动态生成**：根据用户配置动态注入运行环境信息（如浏览器是否可用）
- **数据隔离**：每个容器有独立的 Docker 命名卷，互不干扰
- **普通重装保留插件**：`./setup.sh` 只更新配置，不删卷；`./setup.sh --clean` 彻底清空

## 🔄 更新脚本

```bash
cd ~/openclaw-oneclick

# 拉取最新脚本
git pull

# 重新安装（保留已有插件）
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

**Q: 重装后插件还在吗？**
A: 普通 `./setup.sh` 保留插件和 Skills。`./setup.sh --clean` 彻底清空。

**Q: 浏览器功能怎么用？**
A: 安装时选"是否安装浏览器功能"，会在容器内安装 Chromium。安装后 AI 可直接使用 browser 工具浏览网页、截图、点击等。

## 📖 完整教程

配套详细教程请关注公众号，回复「**教程**」获取。

## 📄 License

MIT
