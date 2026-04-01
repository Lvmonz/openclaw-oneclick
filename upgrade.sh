#!/bin/bash
# ============================================
# 🦞 OpenClaw 一键升级脚本
# 版本: 1.0.0
# 根据安装模式（lite/full）智能升级
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

print_success() { echo -e "  ${GREEN}✔${NC} $1"; }
print_error()   { echo -e "  ${RED}✖${NC} $1"; }
print_warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; }
print_info()    { echo -e "  ${DIM}$1${NC}"; }

# 捕获中断信号
trap 'echo ""; print_warn "升级已取消。"; exit 0' INT TSTP

echo ""
echo -e "${CYAN}${BOLD}  🦞 OpenClaw 一键升级${NC}"
echo -e "${DIM}  ════════════════════════════════${NC}"
echo ""

# 加载配置
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f .env ]; then
    print_error "未找到 .env 配置文件，请先运行 ./setup.sh 安装"
    exit 1
fi

source .env 2>/dev/null
INSTALL_MODE="${INSTALL_MODE:-full}"

echo -e "  ${BOLD}当前安装模式：${NC}${CYAN}${INSTALL_MODE}${NC}"
echo ""

# ==================== 满血版升级 ====================
upgrade_full() {
    echo -e "  ${BLUE}[1/4]${NC} 检查 Docker 环境..."
    if ! docker info &>/dev/null 2>&1; then
        print_error "Docker 未在运行，请先启动 Docker"
        exit 1
    fi
    print_success "Docker 正在运行"

    # 记录当前镜像版本
    local old_core old_browser
    old_core=$(docker inspect openclaw-main --format '{{.Image}}' 2>/dev/null | head -c 16) || old_core="未知"
    old_browser=$(docker inspect openclaw-browser --format '{{.Image}}' 2>/dev/null | head -c 16) || old_browser="未知"

    echo ""
    echo -e "  ${BLUE}[2/4]${NC} 拉取最新镜像..."

    # 构造 compose 命令
    compose_files="-f docker-compose.yml"
    if [ "$SHARE_CHROME" = "yes" ]; then
        compose_files="$compose_files -f docker-compose.browser.yml"
    fi
    if [ -f docker-compose.mirror.yml ]; then
        compose_files="$compose_files -f docker-compose.mirror.yml"
    fi

    local pull_ok=0
    for attempt in 1 2 3; do
        echo -e "    ${DIM}拉取中 (第 ${attempt}/3 次)...${NC}"
        if docker compose $compose_files pull 2>&1 | grep -E '(Pull|Download|Digest|Status|pulling)' || true; then
            pull_ok=1
            break
        fi
        [ $attempt -lt 3 ] && sleep $attempt
    done

    if [ $pull_ok -eq 0 ]; then
        print_error "镜像拉取失败，请检查网络连接"
        exit 1
    fi
    print_success "镜像已更新"

    echo ""
    echo -e "  ${BLUE}[3/4]${NC} 重启容器（保留所有数据和配置）..."
    docker compose $compose_files up -d --remove-orphans 2>/dev/null
    sleep 3
    print_success "容器已重启"

    echo ""
    echo -e "  ${BLUE}[4/4]${NC} 验证升级结果..."
    if docker ps --format '{{.Names}}' | grep -q openclaw-main; then
        local new_core
        new_core=$(docker inspect openclaw-main --format '{{.Image}}' 2>/dev/null | head -c 16) || new_core="未知"
        print_success "openclaw-main 运行正常"
        if [ "$old_core" != "$new_core" ]; then
            print_success "核心镜像已更新: ${old_core} → ${new_core}"
        else
            print_info "核心镜像版本未变化（已是最新）"
        fi
    else
        print_error "openclaw-main 启动异常，请检查：docker compose logs"
        exit 1
    fi

    if [ "$SHARE_CHROME" = "yes" ]; then
        if docker ps --format '{{.Names}}' | grep -q openclaw-browser; then
            print_success "openclaw-browser 运行正常"
        else
            print_warn "openclaw-browser 未启动，可尝试：docker compose $compose_files up -d"
        fi
    fi
}

# ==================== 简易版升级 ====================
upgrade_lite() {
    echo -e "  ${BLUE}[1/2]${NC} 检查 Node.js 环境..."
    if ! command -v node &>/dev/null; then
        print_error "未检测到 Node.js，请先安装 Node.js 22+"
        exit 1
    fi
    print_success "Node.js $(node --version)"

    echo ""
    echo -e "  ${BLUE}[2/2]${NC} 升级 OpenClaw..."
    echo -en "    ${DIM}正在安装最新版..."
    if npm install -g openclaw@latest 2>/dev/null 1>/dev/null; then
        echo -e " ✔${NC}"
        print_success "OpenClaw 已升级到最新版"
    else
        echo -e "${NC}"
        print_warn "npm 全局安装失败，尝试 npx 方式..."
        if npx -y openclaw@latest --version 2>/dev/null 1>/dev/null; then
            print_success "OpenClaw 最新版就绪（npx 模式）"
        else
            print_error "升级失败，请手动运行：npm install -g openclaw@latest"
            exit 1
        fi
    fi
}

# ==================== 主流程 ====================
case "$INSTALL_MODE" in
    lite) upgrade_lite ;;
    full) upgrade_full ;;
    *)
        print_error "未知安装模式: $INSTALL_MODE"
        print_info "请检查 .env 中的 INSTALL_MODE 设置"
        exit 1
        ;;
esac

echo ""
echo -e "${DIM}  ════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}${BOLD}✅ 升级完成！${NC}"
echo ""
echo -e "  ${DIM}所有数据、配置、Skills 均已保留。${NC}"
echo -e "  ${DIM}如需修改配置，请运行 ./setup.sh${NC}"
echo ""
