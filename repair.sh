#!/bin/bash
# ============================================
# 🦞 OpenClaw 一键修复脚本
# 版本: 1.0.0
# 根据安装模式（lite/full）智能诊断与修复
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
print_fix()     { echo -e "  ${CYAN}🔧${NC} $1"; }

trap 'echo ""; print_warn "修复已取消。"; exit 0' INT TSTP

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ISSUES_FOUND=0
ISSUES_FIXED=0

record_issue() { ((ISSUES_FOUND++)); }
record_fix()   { ((ISSUES_FIXED++)); }

echo ""
echo -e "${CYAN}${BOLD}  🦞 OpenClaw 一键修复工具${NC}"
echo -e "${DIM}  ════════════════════════════════${NC}"
echo ""

# ==================== 加载配置 ====================
INSTALL_MODE="full"
if [ -f .env ]; then
    source .env 2>/dev/null
    INSTALL_MODE="${INSTALL_MODE:-full}"
    print_success "配置文件已加载 (模式: ${INSTALL_MODE})"
else
    record_issue
    print_error "缺少 .env 配置文件"
    if [ -f .env.example ]; then
        print_fix "正在从 .env.example 恢复..."
        cp .env.example .env
        record_fix
        print_success "已恢复 .env（请编辑填入真实配置后重新运行 ./setup.sh）"
    else
        print_warn "缺少 .env.example 模板，请重新运行 ./setup.sh"
    fi
fi
echo ""

# ==================== 通用检查 ====================

echo -e "  ${BOLD}[1/6] 文件完整性检查${NC}"
echo -e "  ${DIM}────────────────────────────────${NC}"

required_files=("setup.sh" "docker-compose.yml" ".env")
if [ "$INSTALL_MODE" = "full" ] && [ "$SHARE_CHROME" = "yes" ]; then
    required_files+=("docker-compose.browser.yml")
fi

for f in "${required_files[@]}"; do
    if [ -f "$f" ]; then
        print_success "$f"
    else
        record_issue
        print_error "缺少 $f"
        # 尝试从 git 恢复
        if git checkout -- "$f" 2>/dev/null; then
            record_fix
            print_fix "已从 git 恢复 $f"
        fi
    fi
done

# 脚本可执行权限
for script in setup.sh upgrade.sh repair.sh factory-reset.sh; do
    if [ -f "$script" ] && [ ! -x "$script" ]; then
        record_issue
        chmod +x "$script"
        record_fix
        print_fix "已修复 $script 可执行权限"
    fi
done
echo ""

# ==================== 模式特定检查 ====================

if [ "$INSTALL_MODE" = "full" ]; then
    # ── Docker 环境检查 ──
    echo -e "  ${BOLD}[2/6] Docker 环境检查${NC}"
    echo -e "  ${DIM}────────────────────────────────${NC}"

    if command -v docker &>/dev/null; then
        print_success "Docker 已安装"
    else
        record_issue
        print_error "Docker 未安装"
        print_info "请安装 Docker: https://docker.com/get-started"
    fi

    if docker info &>/dev/null 2>&1; then
        print_success "Docker 正在运行"
    else
        record_issue
        print_error "Docker 未运行"
        if [ "$(uname -s)" = "Linux" ]; then
            print_fix "尝试启动 Docker..."
            sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
            sleep 2
            if docker info &>/dev/null 2>&1; then
                record_fix
                print_success "Docker 已启动"
            else
                print_error "Docker 启动失败，请手动启动"
            fi
        else
            print_info "请启动 Docker Desktop"
        fi
    fi

    if docker compose version &>/dev/null; then
        print_success "Docker Compose 可用"
    else
        record_issue
        print_error "Docker Compose 不可用"
    fi
    echo ""

    # ── 容器健康检查 ──
    echo -e "  ${BOLD}[3/6] 容器健康检查${NC}"
    echo -e "  ${DIM}────────────────────────────────${NC}"

    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q openclaw-main; then
        print_success "openclaw-main 正在运行"
        # 检查容器内配置
        if docker exec openclaw-main test -f /home/node/.openclaw/openclaw.json 2>/dev/null; then
            print_success "openclaw.json 配置存在"
        else
            record_issue
            print_error "容器内缺少 openclaw.json"
            print_fix "请重新运行 ./setup.sh 注入配置"
        fi
    else
        record_issue
        print_error "openclaw-main 未运行"
        print_fix "尝试重新启动..."
        compose_files="-f docker-compose.yml"
        [ "$SHARE_CHROME" = "yes" ] && compose_files="$compose_files -f docker-compose.browser.yml"
        [ -f docker-compose.mirror.yml ] && compose_files="$compose_files -f docker-compose.mirror.yml"
        if docker compose $compose_files up -d 2>/dev/null; then
            sleep 3
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q openclaw-main; then
                record_fix
                print_success "openclaw-main 已恢复"
            else
                print_error "启动失败，请检查：docker compose logs"
            fi
        fi
    fi

    if [ "$SHARE_CHROME" = "yes" ]; then
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q openclaw-browser; then
            print_success "openclaw-browser 正在运行"
        else
            record_issue
            print_warn "openclaw-browser 未运行"
        fi
    fi
    echo ""

    # ── 端口检查 ──
    echo -e "  ${BOLD}[4/6] 端口占用检查${NC}"
    echo -e "  ${DIM}────────────────────────────────${NC}"

    check_port() {
port=$1 name=$2
        if lsof -i :"$port" &>/dev/null 2>&1 || ss -tlnp 2>/dev/null | grep -q ":$port "; then
pid
            pid=$(lsof -ti :"$port" 2>/dev/null | head -1)
            if [ -n "$pid" ]; then
pname
                pname=$(ps -p "$pid" -o comm= 2>/dev/null)
                if echo "$pname" | grep -qi docker; then
                    print_success "端口 $port ($name) — Docker 占用 ✓"
                else
                    record_issue
                    print_warn "端口 $port ($name) — 被 $pname (PID:$pid) 占用"
                    print_info "释放方法：kill $pid 或 sudo lsof -ti :$port | xargs kill"
                fi
            else
                print_success "端口 $port ($name) — 已使用"
            fi
        else
            print_info "端口 $port ($name) — 空闲"
        fi
    }

    check_port 18789 "OpenClaw Gateway"
    [ "$SHARE_CHROME" = "yes" ] && check_port 9222 "Sidecar Browser"
    echo ""

    # ── Volume 检查 ──
    echo -e "  ${BOLD}[5/6] 数据卷检查${NC}"
    echo -e "  ${DIM}────────────────────────────────${NC}"

    local_prefix=$(basename "$(pwd)")
    for vol in "${local_prefix}_openclaw-data" "${local_prefix}_browser_profile"; do
        if docker volume inspect "$vol" &>/dev/null 2>&1; then
            vol_info=$(docker system df -v 2>/dev/null | grep "$vol" | awk '{print $4}' || echo "未知")
            print_success "$vol ($vol_info)"
        else
            if [[ "$vol" == *"browser_profile"* ]] && [ "$SHARE_CHROME" != "yes" ]; then
                print_info "$vol — 未使用（浏览器未启用）"
            else
                record_issue
                print_warn "$vol — 不存在（数据可能丢失）"
            fi
        fi
    done

    # 磁盘空间
    if command -v df &>/dev/null; then
        disk_avail=$(df -h "$PWD" | awk 'NR==2 {print $4}' 2>/dev/null || df -h . | awk 'NR==2 {print $4}')
        print_info "可用磁盘空间: $disk_avail"
    fi
    echo ""

else
    # ── 简易版检查 ──
    echo -e "  ${BOLD}[2/6] Node.js 环境检查${NC}"
    echo -e "  ${DIM}────────────────────────────────${NC}"

    if command -v node &>/dev/null; then
node_ver
        node_ver=$(node --version)
        print_success "Node.js $node_ver"
major
        major=$(echo "$node_ver" | sed 's/v//' | cut -d. -f1)
        if [ "$major" -lt 22 ]; then
            record_issue
            print_warn "建议 Node.js 22+，当前 $node_ver"
        fi
    else
        record_issue
        print_error "未检测到 Node.js"
        print_info "请安装：https://nodejs.org/"
    fi

    if command -v npm &>/dev/null; then
        print_success "npm $(npm --version 2>/dev/null)"
    else
        record_issue
        print_error "未检测到 npm"
    fi

    if command -v openclaw &>/dev/null; then
        print_success "openclaw CLI 已安装"
    else
        record_issue
        print_warn "openclaw CLI 未全局安装"
        print_info "安装：npm install -g openclaw@latest"
    fi
    echo ""

    echo -e "  ${BOLD}[3/6] 本地浏览器检查${NC}"
    echo -e "  ${DIM}────────────────────────────────${NC}"
    # 检测本地 Chrome 是否可用于 CDP
    if command -v google-chrome &>/dev/null || command -v "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" &>/dev/null 2>&1; then
        print_success "Google Chrome 已安装"
    else
        print_warn "未检测到 Chrome（部分功能可能受限）"
    fi
    echo ""

    echo -e "  ${BOLD}[4/6] 跳过（Docker 专属）${NC}"
    print_info "简易版不使用 Docker，跳过容器检查"
    echo ""
    echo -e "  ${BOLD}[5/6] 跳过（Docker 专属）${NC}"
    print_info "简易版不使用 Docker，跳过数据卷检查"
    echo ""
fi

# ==================== 日志管理 ====================

echo -e "  ${BOLD}[6/6] 安装日志管理${NC}"
echo -e "  ${DIM}────────────────────────────────${NC}"

LOG_DIR="$SCRIPT_DIR/logs"
if [ -d "$LOG_DIR" ]; then
log_count
    log_count=$(find "$LOG_DIR" -name "install_*.log" 2>/dev/null | wc -l | tr -d ' ')
    print_info "安装日志: ${log_count} 个"

    # 清理超过 24h 的日志
old_count
    old_count=$(find "$LOG_DIR" -name "install_*.log" -mtime +1 2>/dev/null | wc -l | tr -d ' ')
    if [ "$old_count" -gt 0 ]; then
        find "$LOG_DIR" -name "install_*.log" -mtime +1 -delete 2>/dev/null
        print_fix "已清理 ${old_count} 个过期日志（>24h）"
    fi
else
    print_info "尚无安装日志"
fi
echo ""

# ==================== 诊断报告 ====================

echo -e "${DIM}  ════════════════════════════════${NC}"
echo ""
if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✅ 系统状态良好，未发现问题！${NC}"
elif [ $ISSUES_FIXED -eq $ISSUES_FOUND ]; then
    echo -e "  ${GREEN}${BOLD}✅ 发现 ${ISSUES_FOUND} 个问题，全部已自动修复！${NC}"
else
remaining=$((ISSUES_FOUND - ISSUES_FIXED))
    echo -e "  ${YELLOW}${BOLD}⚠ 发现 ${ISSUES_FOUND} 个问题，已修复 ${ISSUES_FIXED} 个，${remaining} 个需手动处理${NC}"
fi
echo ""

# ==================== 日志导出 ====================

echo -e "  ${BOLD}是否导出诊断日志？${NC}"
echo -e "  ${GREEN}1)${NC} 导出到文件"
echo -e "  ${GREEN}2)${NC} 跳过"
echo ""
echo -en "  选择 ${DIM}[2]${NC}: "
read -r export_choice
export_choice=${export_choice:-2}

if [ "$export_choice" = "1" ]; then
    # 尝试文件选择器（macOS osascript / Linux zenity）
export_path=""
default_name="openclaw_diag_$(date +%Y%m%d_%H%M%S).log"

    if [ "$(uname -s)" = "Darwin" ] && command -v osascript &>/dev/null; then
        export_path=$(osascript -e "
            set savePath to POSIX path of (choose file name with prompt \"保存诊断日志\" default name \"${default_name}\" default location (path to desktop))
        " 2>/dev/null) || true
    elif command -v zenity &>/dev/null; then
        export_path=$(zenity --file-selection --save --confirm-overwrite --filename="$default_name" --title="保存诊断日志" 2>/dev/null) || true
    fi

    # 回退到终端输入
    if [ -z "$export_path" ]; then
        echo -en "  输入保存路径 ${DIM}[~/Desktop/${default_name}]${NC}: "
        read -r export_path
        export_path="${export_path:-$HOME/Desktop/${default_name}}"
    fi

    # 展开 ~ 路径
    export_path="${export_path/#\~/$HOME}"

    # 生成诊断日志
    {
        echo "========================================"
        echo "OpenClaw 诊断日志"
        echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "安装模式: ${INSTALL_MODE}"
        echo "操作系统: $(uname -s) $(uname -m)"
        echo "========================================"
        echo ""
        echo "--- .env 配置（脱敏） ---"
        if [ -f .env ]; then
            sed 's/\(API_KEY=\).*/\1****/' .env | sed 's/\(TOKEN=\).*/\1****/'
        fi
        echo ""
        if [ "$INSTALL_MODE" = "full" ]; then
            echo "--- Docker 信息 ---"
            docker version 2>/dev/null || echo "Docker 不可用"
            echo ""
            echo "--- 容器状态 ---"
            docker ps -a --filter "name=openclaw" 2>/dev/null || echo "无法获取"
            echo ""
            echo "--- 容器日志（最近 50 行）---"
            docker logs openclaw-main --tail 50 2>/dev/null || echo "无法获取"
            echo ""
            echo "--- 数据卷 ---"
            docker volume ls --filter "name=openclaw" 2>/dev/null || echo "无法获取"
        else
            echo "--- Node.js 信息 ---"
            node --version 2>/dev/null || echo "Node.js 不可用"
            npm --version 2>/dev/null || echo "npm 不可用"
        fi
        echo ""
        echo "--- 安装日志 ---"
        if [ -d "$LOG_DIR" ]; then
latest_log
            latest_log=$(ls -t "$LOG_DIR"/install_*.log 2>/dev/null | head -1)
            if [ -n "$latest_log" ]; then
                echo "最新日志: $latest_log"
                tail -100 "$latest_log"
            else
                echo "无安装日志"
            fi
        fi
    } > "$export_path" 2>/dev/null

    if [ -f "$export_path" ]; then
        print_success "诊断日志已导出到: $export_path"
    else
        print_error "导出失败，请检查路径权限"
    fi
fi

echo ""
