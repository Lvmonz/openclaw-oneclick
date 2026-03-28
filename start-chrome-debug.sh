#!/bin/bash
# ============================================================
# start-chrome-debug.sh — 启动 Chrome 远程调试模式
# 让 Docker 容器中的 OpenClaw 通过 CDP 控制你的浏览器
# ============================================================

PORT="${1:-9222}"

echo ""
echo "🌐 启动 Chrome 远程调试模式 (端口: $PORT)"
echo "================================================"
echo ""

# 检测 Chrome 路径
CHROME_BIN=""
if [ "$(uname)" = "Darwin" ]; then
    CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
elif command -v google-chrome &>/dev/null; then
    CHROME_BIN="google-chrome"
elif command -v chromium-browser &>/dev/null; then
    CHROME_BIN="chromium-browser"
elif command -v chromium &>/dev/null; then
    CHROME_BIN="chromium"
fi

if [ -z "$CHROME_BIN" ] || [ ! -f "$CHROME_BIN" ] && ! command -v "$CHROME_BIN" &>/dev/null; then
    echo "❌ 未找到 Chrome，请先安装 Google Chrome"
    exit 1
fi

echo "✔ 找到 Chrome: $CHROME_BIN"
echo ""
echo "⚠️  注意事项："
echo "   • Chrome 将以调试模式启动，AI 可以看到和操作你的浏览器"
echo "   • AI 能访问所有已登录的网站（和你手动操作完全一样）"
echo "   • 关闭此终端窗口即可停止调试模式"
echo ""
echo "🚀 正在启动..."
echo ""

"$CHROME_BIN" \
    --remote-debugging-port="$PORT" \
    --remote-allow-origins="*" \
    --no-first-run \
    --no-default-browser-check \
    2>/dev/null &

sleep 2

# 验证是否启动成功
if curl -s "http://localhost:$PORT/json/version" > /dev/null 2>&1; then
    echo "✅ Chrome 调试模式已启动！"
    echo ""
    echo "   调试端口: localhost:$PORT"
    echo "   OpenClaw 连接地址: host.docker.internal:$PORT"
    echo ""
    echo "   现在可以运行 ./setup.sh 或重启容器让 AI 连接浏览器"
    echo "   按 Ctrl+C 关闭调试模式"
    echo ""
    wait
else
    echo "❌ Chrome 启动失败，请检查是否有其他 Chrome 实例占用端口"
    echo "   尝试：先关闭所有 Chrome 窗口，再运行此脚本"
fi
