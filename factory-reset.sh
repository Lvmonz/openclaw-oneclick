#!/bin/bash
# ==============================================================================
# 🦞 OpenClaw 出厂重置脚本 (factory-reset.sh)
#
# 功能：清除 OpenClaw 的全部对话记忆、日志、浏览器缓存，恢复到"出厂"状态。
# 保留：已安装的 Skills、workspace 配置文件（SOUL.md/IDENTITY.md 等）、微信绑定
#
# 使用：bash factory-reset.sh [--hard]
#   --hard  额外清除浏览器 Cookie/登录态（需要重新扫码登录各网站）
# ==============================================================================

set -e

HARD_RESET=false
if [ "$1" = "--hard" ]; then
    HARD_RESET=true
fi

echo "🦞 OpenClaw 出厂重置"
echo "============================================="

# ── 定位容器 ──────────────────────────────────
CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep -i 'openclaw' | grep -iv 'browser' | head -1)
BROWSER_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i 'openclaw-browser' | head -1)

if [ -z "$CONTAINER_NAME" ]; then
    echo "❌ 未找到正在运行的 OpenClaw 核心容器"
    exit 1
fi

echo "📦 核心容器: $CONTAINER_NAME"
[ -n "$BROWSER_CONTAINER" ] && echo "🌐 浏览器容器: $BROWSER_CONTAINER"

# ── 1. 清空对话历史 ──────────────────────────────
echo ""
echo "🧹 [1/4] 清空对话历史..."
docker exec "$CONTAINER_NAME" sh -c "
    # 删除所有会话记录文件
    rm -rf /home/node/.openclaw/agents/main/sessions/*.jsonl \
           /home/node/.openclaw/agents/main/sessions/*.jsonl.reset.* \
           2>/dev/null || true

    # 重置会话路由映射（防止残留的 session 元数据指向旧对话）
    echo '{}' > /home/node/.openclaw/agents/main/sessions/sessions.json
"
echo "   ✅ 对话历史已清空"

# ── 2. 清空记忆与日志 ──────────────────────────────
echo "🧹 [2/4] 清空记忆与日志..."
docker exec "$CONTAINER_NAME" sh -c "
    # 清空 Agent 记忆
    rm -rf /home/node/.openclaw/workspace/memory/* \
           /home/node/.openclaw/workspace/MEMORY.md \
           2>/dev/null || true

    # 清空日志
    rm -rf /home/node/.openclaw/logs/* \
           2>/dev/null || true

    # 清空临时文件
    rm -rf /tmp/openclaw/* /tmp/ctrip_* /tmp/*.png \
           2>/dev/null || true
"
echo "   ✅ 记忆与日志已清空"

# ── 3. 清空 LLM 缓存 ──────────────────────────────
echo "🧹 [3/4] 清空 LLM prompt cache..."
docker exec "$CONTAINER_NAME" sh -c "
    # 清空微信通道的 context-tokens 缓存
    # （防止 LLM 提供商的 prompt cache 保留旧的系统提示词）
    rm -f /home/node/.openclaw/openclaw-weixin/accounts/*context-tokens* \
          2>/dev/null || true
"
echo "   ✅ LLM 缓存已清空"

# ── 4. 清空浏览器状态 ──────────────────────────────
if [ "$HARD_RESET" = true ]; then
    echo "🧹 [4/4] 清空浏览器缓存与 Cookie (--hard)..."
    # 清空 workspace 中的登录态文件
    docker exec "$CONTAINER_NAME" sh -c "
        rm -f /home/node/.openclaw/workspace/ctrip_cookies.json \
              /home/node/.openclaw/workspace/.auth \
              2>/dev/null || true
        # 清空所有 skill 目录下的 cookies 文件
        find /home/node/.openclaw/skills -name '*cookie*' -not -path '*/node_modules/*' -delete 2>/dev/null || true
    "
    if [ -n "$BROWSER_CONTAINER" ]; then
        docker exec -u root "$BROWSER_CONTAINER" sh -c "rm -rf /home/browserless/chrome/user-data/* 2>/dev/null || true"
        echo "   ✅ 浏览器缓存与 Cookie 已清空（需重新登录各网站）"
    else
        echo "   ⚠️ 未找到浏览器容器，仅清空了 workspace 中的登录态"
    fi
else
    echo "ℹ️  [4/4] 跳过浏览器缓存清理（使用 --hard 可一并清除）"
fi

# ── 重启容器 ──────────────────────────────────────
echo ""
echo "🔄 正在重启容器..."
if [ -n "$BROWSER_CONTAINER" ] && [ "$HARD_RESET" = true ]; then
    docker restart "$CONTAINER_NAME" "$BROWSER_CONTAINER"
    echo "   ✅ 核心容器 + 浏览器容器 已重启"
else
    docker restart "$CONTAINER_NAME"
    echo "   ✅ 核心容器已重启"
fi

# ── 完成 ──────────────────────────────────────────
echo ""
echo "============================================="
echo "🎉 OpenClaw 已恢复出厂状态！"
echo ""
echo "📌 以下内容已保留："
echo "   • 已安装的 Skills (/skills/*)"
echo "   • 配置文件 (SOUL.md, IDENTITY.md, USER.md 等)"
echo "   • 微信账号绑定"
if [ "$HARD_RESET" = false ]; then
    echo "   • 浏览器 Cookie 与登录态 (使用 --hard 可清除)"
fi
echo "============================================="
