#!/bin/bash
# ============================================
# 🦞 OpenClaw 一键卸载脚本
# 版本: 1.0.0
# 支持选择性保留 Skills 或彻底清除一切痕迹
# ============================================

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

trap 'echo ""; print_warn "卸载已取消。"; exit 0' INT TSTP

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo -e "${RED}${BOLD}  🦞 OpenClaw 一键卸载${NC}"
echo -e "${DIM}  ════════════════════════════════${NC}"
echo ""

# 加载配置
INSTALL_MODE="full"
if [ -f .env ]; then
    source .env 2>/dev/null
    INSTALL_MODE="${INSTALL_MODE:-full}"
fi

echo -e "  ${BOLD}选择卸载方式：${NC}"
echo ""
echo -e "  ${YELLOW}1)${NC} 🧹 标准卸载"
echo -e "     ${DIM}移除容器和镜像，但保留 Skills 和用户配置${NC}"
echo -e "     ${DIM}下次安装时可快速恢复${NC}"
echo ""
echo -e "  ${RED}2)${NC} 💣 彻底卸载"
echo -e "     ${DIM}移除一切 OpenClaw 存在的痕迹${NC}"
echo -e "     ${DIM}包括：容器、镜像、数据卷、配置、Skills、日志、缓存${NC}"
echo ""
echo -e "  ${GREEN}3)${NC} 取消"
echo ""
echo -en "  选择 ${DIM}[3]${NC}: "
read -r choice
choice=${choice:-3}

if [ "$choice" = "3" ]; then
    echo ""
    print_info "已取消卸载。"
    echo ""
    exit 0
fi

FULL_REMOVE=false
[ "$choice" = "2" ] && FULL_REMOVE=true

# ==================== 二次确认 ====================

echo ""
if [ "$FULL_REMOVE" = true ]; then
    echo -e "  ${RED}${BOLD}⚠ 警告：彻底卸载将删除所有数据，此操作不可逆！${NC}"
    echo ""
    echo -e "  将被删除的内容："
    echo -e "    • Docker 容器（openclaw-main, openclaw-browser）"
    echo -e "    • Docker 数据卷（openclaw-data, browser_profile）"
    echo -e "    • Docker 镜像（openclaw, chromium）"
    echo -e "    • 配置文件（.env, openclaw.json）"
    echo -e "    • 安装日志（logs/）"
    echo -e "    • 所有 Skills 和 Workspace 数据"
    echo -e "    • 浏览器登录态（Cookie、Session）"
    echo ""
    echo -en "  ${RED}输入 YES 确认彻底卸载${NC}: "
    read -r confirm
    if [ "$confirm" != "YES" ]; then
        echo ""
        print_info "已取消。确认卸载请输入大写 YES。"
        echo ""
        exit 0
    fi
else
    echo -e "  ${YELLOW}将执行标准卸载（保留 Skills 和用户配置）${NC}"
    echo -en "  确认？${DIM}[y/N]${NC}: "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo ""
        print_info "已取消卸载。"
        echo ""
        exit 0
    fi
fi

echo ""
echo -e "  ${BOLD}开始卸载...${NC}"
echo ""

# ==================== 满血版卸载 ====================

if [ "$INSTALL_MODE" = "full" ]; then
    # Step 1: 停止并移除容器
    echo -e "  ${BLUE}[1/5]${NC} 停止并移除容器..."
    compose_files="-f docker-compose.yml"
    [ -f docker-compose.browser.yml ] && compose_files="$compose_files -f docker-compose.browser.yml"
    [ -f docker-compose.mirror.yml ] && compose_files="$compose_files -f docker-compose.mirror.yml"

    docker compose $compose_files kill 2>/dev/null || true
    docker compose $compose_files down --remove-orphans -t 1 2>/dev/null || true

    # 确保容器已被移除
    docker rm -f openclaw-main 2>/dev/null || true
    docker rm -f openclaw-browser 2>/dev/null || true
    print_success "容器已移除"

    # Step 2: 数据卷
    echo -e "  ${BLUE}[2/5]${NC} 处理数据卷..."
    local_prefix=$(basename "$(pwd)")

    if [ "$FULL_REMOVE" = true ]; then
        docker volume rm "${local_prefix}_openclaw-data" 2>/dev/null && print_success "数据卷 openclaw-data 已删除" || print_info "数据卷 openclaw-data 不存在"
        docker volume rm "${local_prefix}_browser_profile" 2>/dev/null && print_success "浏览器数据卷 browser_profile 已删除" || print_info "浏览器数据卷不存在"
    else
        print_info "标准卸载：保留数据卷（下次安装可恢复）"
        print_info "手动删除：docker volume rm ${local_prefix}_openclaw-data"
    fi

    # Step 3: 镜像
    echo -e "  ${BLUE}[3/5]${NC} 处理 Docker 镜像..."
    if [ "$FULL_REMOVE" = true ]; then
        # 移除 OpenClaw 相关镜像
        docker rmi ghcr.io/openclaw/openclaw:latest 2>/dev/null && print_success "openclaw 镜像已删除" || true
        docker rmi ghcr.io/browserless/chromium:latest 2>/dev/null && print_success "chromium 镜像已删除" || true
        # 清理 DaoCloud 镜像（如果使用了国内镜像）
        docker rmi docker.m.daocloud.io/browserless/chromium:latest 2>/dev/null || true
        # 清理悬空镜像
        docker image prune -f 2>/dev/null || true
        print_success "相关镜像已清理"
    else
        print_info "标准卸载：保留镜像（下次安装更快）"
    fi

else
    # ── 简易版卸载 ──
    echo -e "  ${BLUE}[1/5]${NC} 简易版环境清理..."
    if [ "$FULL_REMOVE" = true ]; then
        # 移除全局安装的 openclaw
        npm uninstall -g openclaw 2>/dev/null && print_success "openclaw CLI 已卸载" || print_info "openclaw CLI 未全局安装"
        # 清空 ~/.openclaw 目录
        if [ -d "$HOME/.openclaw" ]; then
            rm -rf "$HOME/.openclaw"
            print_success "~/.openclaw 目录已删除"
        fi
    else
        print_info "标准卸载：保留全局 CLI 和 ~/.openclaw 数据"
    fi
    echo -e "  ${BLUE}[2/5]${NC} 跳过（Docker 专属）"
    echo -e "  ${BLUE}[3/5]${NC} 跳过（Docker 专属）"
fi

# Step 4: 本地文件
echo -e "  ${BLUE}[4/5]${NC} 处理本地配置文件..."
if [ "$FULL_REMOVE" = true ]; then
    # 删除 .env
    [ -f .env ] && rm -f .env && print_success ".env 已删除"
    # 删除日志
    [ -d logs ] && rm -rf logs && print_success "安装日志已删除"
    # 删除镜像 override
    [ -f docker-compose.mirror.yml ] && rm -f docker-compose.mirror.yml && print_success "镜像加速配置已删除"
    # 清理系统级缓存
    if [ -d "$HOME/.cache/openclaw" ]; then
        rm -rf "$HOME/.cache/openclaw"
        print_success "用户缓存已清理"
    fi
    # 清理 npm 缓存中的 openclaw 相关
    npm cache ls 2>/dev/null | grep -i openclaw | while read -r line; do
        npm cache rm "$line" 2>/dev/null
    done
    print_success "本地文件已全部清理"
else
    print_info "标准卸载：保留 .env 和日志"
fi

# Step 5: 完成
echo -e "  ${BLUE}[5/5]${NC} 卸载完成"
echo ""
echo -e "${DIM}  ════════════════════════════════${NC}"
echo ""

if [ "$FULL_REMOVE" = true ]; then
    echo -e "  ${GREEN}${BOLD}✅ OpenClaw 已彻底卸载！${NC}"
    echo ""
    echo -e "  ${DIM}所有 OpenClaw 相关的容器、镜像、数据、配置、缓存已全部清除。${NC}"
    echo -e "  ${DIM}如需重新安装，请重新克隆项目并运行 ./setup.sh${NC}"
else
    echo -e "  ${GREEN}${BOLD}✅ OpenClaw 标准卸载完成！${NC}"
    echo ""
    echo -e "  ${DIM}已保留：${NC}"
    echo -e "  ${DIM}  • 数据卷（Skills、工作区数据）${NC}"
    echo -e "  ${DIM}  • Docker 镜像（加快下次安装）${NC}"
    echo -e "  ${DIM}  • .env 配置文件${NC}"
    echo -e "  ${DIM}重新安装只需运行 ./setup.sh${NC}"
fi
echo ""
