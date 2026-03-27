# 🦞 OpenClaw 一键安装脚本

一个脚本 + 一个 `.env` 文件，5 分钟完成 OpenClaw 的完整部署。

## ✨ 一键搞定

- Docker 沙盒环境（类 conda 隔离）
- New-api + Anthropic Claude 模型配置
- 双模型路由 + Prompt 缓存优化
- Soul / User / Agents MD 模板初始化
- 5 个核心 Skills 自动安装
- 个人微信（ClawChat）接入
- 网关自动重启

## 📦 文件说明

```
openclaw-oneclick/
├── setup.sh              # 主安装脚本（自动 7 步）
├── .env.example          # 环境变量模板
├── docker-compose.yml    # Docker 编排配置
├── .gitignore            # 防止 .env 和数据泄露
└── templates/            # MD 文件模板
    ├── SOUL.md           # AI 人格定义
    ├── AGENTS.md         # 权限控制
    └── MEMORY.md         # 记忆初始化
```

## 🚀 快速开始

### 前置要求

- Docker Desktop（[下载地址](https://docker.com/get-started)）
- 模型 API Key（推荐通过 [New-api](https://github.com/Calcium-Ion/new-api) 管理）

### 3 步安装

```bash
# 1. 克隆项目
git clone https://github.com/Lvmonz/openclaw-oneclick.git
cd openclaw-oneclick

# 2. 配置环境变量（唯一需要手动填写的步骤）
cp .env.example .env
nano .env   # 填入你的 API Key 等配置

# 3. 运行安装
chmod +x setup.sh
./setup.sh
```

### 预期输出

```
🦞 OpenClaw 一键安装脚本
========================
📦 Step 1: 创建目录结构...
🐳 Step 2: 启动 Docker 容器...
📝 Step 3: 生成 openclaw.json...
📋 Step 4: 复制 MD 模板...
🔌 Step 5: 安装必装 Skills...
📱 Step 6: 配置微信通道...
🔄 Step 7: 重启网关...

✅ 安装完成！
================================
管理面板: http://localhost:18789
查看日志: docker compose logs -f
进入容器: docker exec -it openclaw-main bash
================================
```

## ⚙️ .env 配置说明

| 变量 | 必填 | 说明 |
|------|------|------|
| `NEWAPI_BASE_URL` | ✅ | New-api 地址，末尾必须有 `/v1` |
| `NEWAPI_API_KEY` | ✅ | New-api 生成的 Token |
| `PRIMARY_MODEL` | ✅ | 日常对话模型 |
| `THINKING_MODEL` | ✅ | 深度推理模型 |
| `CLAWCHAT_API_KEY` | ❌ | ClawChat 微信机器人 Key |
| `BRAVE_API_KEY` | ❌ | Brave Search API Key |
| `USER_NAME` | ❌ | 你的名字（写入 User.md） |

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

## 💾 备份与恢复

```bash
# 备份
cd ~/openclaw-oneclick
docker compose down
tar -czf ~/openclaw-backup-$(date +%Y%m%d).tar.gz .

# 恢复到新机器
tar -xzf openclaw-backup-*.tar.gz -C ~/openclaw-oneclick/
cd ~/openclaw-oneclick && docker compose up -d
```

> ⚠️ 备份包含 API Key，传输时建议加密：`tar -czf - . | gpg -c > backup.tar.gz.gpg`

## 🗑️ 彻底卸载

```bash
cd ~/openclaw-oneclick
docker compose down -v
docker rmi openclaw/openclaw:latest
cd ~ && rm -rf ~/openclaw-oneclick
docker system prune -f   # 可选
```

## ❓ 常见问题

**Q: `/status` 显示 Provider 为空**
A: 检查 `.env` 中 `NEWAPI_BASE_URL` 末尾是否有 `/v1`。

**Q: 模型调用返回 400 错误**
A: 确认 `api` 是 `"anthropic-messages"`，不是 `"openai-completions"`。

**Q: 想让 AI 访问本地文件**
A: 在 `docker-compose.yml` 的 `volumes` 中添加 `- ~/Documents:/root/documents:ro`。

## 📖 完整教程

配套详细教程请关注公众号，回复「**教程**」获取。

## 📄 License

MIT
