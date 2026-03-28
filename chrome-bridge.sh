#!/bin/bash
# ============================================================
# chrome-bridge.sh — Chrome 控制桥接服务
# 让 Docker 容器中的 OpenClaw 通过 HTTP 按需启动/关闭 Chrome
#
# 用法：./chrome-bridge.sh          (默认端口 9223)
#       ./chrome-bridge.sh 8080     (自定义端口)
#
# API:
#   GET /start  — 启动 Chrome 调试模式
#   GET /stop   — 关闭 Chrome 调试实例
#   GET /status — 检查 Chrome 是否在运行
# ============================================================

BRIDGE_PORT="${1:-9223}"
CDP_PORT="9222"
CDP_PROFILE="/tmp/chrome-cdp-profile"
CHROME_PID=""

# 检测 Chrome 路径
detect_chrome() {
    if [ "$(uname)" = "Darwin" ]; then
        echo "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    elif command -v google-chrome &>/dev/null; then
        echo "google-chrome"
    elif command -v chromium-browser &>/dev/null; then
        echo "chromium-browser"
    elif command -v chromium &>/dev/null; then
        echo "chromium"
    else
        echo ""
    fi
}

CHROME_BIN=$(detect_chrome)

start_chrome() {
    if [ -z "$CHROME_BIN" ]; then
        echo '{"ok":false,"error":"Chrome not found"}'
        return 1
    fi

    # 检查是否已在运行
    if [ -n "$CHROME_PID" ] && kill -0 "$CHROME_PID" 2>/dev/null; then
        echo '{"ok":true,"message":"already running","pid":'"$CHROME_PID"'}'
        return 0
    fi

    mkdir -p "$CDP_PROFILE"
    "$CHROME_BIN" \
        --remote-debugging-port="$CDP_PORT" \
        --remote-allow-origins="*" \
        --user-data-dir="$CDP_PROFILE" \
        --no-first-run \
        --no-default-browser-check \
        >/dev/null 2>&1 &
    CHROME_PID=$!

    # 等待端口就绪
    for i in $(seq 1 10); do
        sleep 1
        if curl -s "http://localhost:$CDP_PORT/json/version" > /dev/null 2>&1; then
            echo '{"ok":true,"message":"started","pid":'"$CHROME_PID"',"cdp_port":'"$CDP_PORT"'}'
            return 0
        fi
    done

    echo '{"ok":false,"error":"Chrome started but CDP port not ready"}'
    return 1
}

stop_chrome() {
    if [ -n "$CHROME_PID" ] && kill -0 "$CHROME_PID" 2>/dev/null; then
        kill "$CHROME_PID" 2>/dev/null
        wait "$CHROME_PID" 2>/dev/null
        CHROME_PID=""
        echo '{"ok":true,"message":"stopped"}'
    else
        CHROME_PID=""
        echo '{"ok":true,"message":"not running"}'
    fi
}

status_chrome() {
    if [ -n "$CHROME_PID" ] && kill -0 "$CHROME_PID" 2>/dev/null; then
        if curl -s "http://localhost:$CDP_PORT/json/version" > /dev/null 2>&1; then
            echo '{"ok":true,"running":true,"pid":'"$CHROME_PID"',"cdp_port":'"$CDP_PORT"'}'
        else
            echo '{"ok":true,"running":true,"pid":'"$CHROME_PID"',"cdp_ready":false}'
        fi
    else
        echo '{"ok":true,"running":false}'
    fi
}

# 清理
cleanup() {
    echo ""
    echo "🛑 正在关闭..."
    stop_chrome > /dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

# ==================== 启动服务 ====================

echo ""
echo "🌉 Chrome Bridge 服务"
echo "================================"
echo ""
echo "  桥接端口: localhost:$BRIDGE_PORT"
echo "  CDP 端口: localhost:$CDP_PORT"
echo "  Chrome Profile: $CDP_PROFILE"
echo ""
echo "  API:"
echo "    curl http://localhost:$BRIDGE_PORT/start   # 启动 Chrome"
echo "    curl http://localhost:$BRIDGE_PORT/stop    # 关闭 Chrome"
echo "    curl http://localhost:$BRIDGE_PORT/status  # 检查状态"
echo ""
echo "  Docker 内调用:"
echo "    curl http://host.docker.internal:$BRIDGE_PORT/start"
echo ""
echo "  按 Ctrl+C 关闭服务"
echo ""

# 用 bash 内置的 /dev/tcp 或 nc 作为简易 HTTP 服务器
while true; do
    # 使用 nc (netcat) 监听
    request=$(echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n" | nc -l "$BRIDGE_PORT" 2>/dev/null | head -1)

    # 解析请求路径
    path=$(echo "$request" | awk '{print $2}')

    case "$path" in
        /start)
            result=$(start_chrome)
            echo "[$(date '+%H:%M:%S')] /start → $result"
            ;;
        /stop)
            result=$(stop_chrome)
            echo "[$(date '+%H:%M:%S')] /stop → $result"
            ;;
        /status)
            result=$(status_chrome)
            echo "[$(date '+%H:%M:%S')] /status → $result"
            ;;
        *)
            echo "[$(date '+%H:%M:%S')] $path → unknown"
            ;;
    esac
done
