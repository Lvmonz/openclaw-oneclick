#!/bin/bash
# ============================================
# 🦞 OpenClaw 一键安装脚本（交互式）
# 版本: 1.0.0
# ============================================

# 注意：不使用 set -e，关键步骤手动检查错误

# ==================== 工具函数 ====================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

print_header() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}  🦞 OpenClaw 一键安装向导${NC}"
    echo -e "${DIM}  ════════════════════════════════${NC}"
    echo ""
}

print_step() {
    local current=$1
    local total=5
    local title=$2
    echo -e "  ${BLUE}[Step $current/$total]${NC} ${BOLD}$title${NC}"
    echo -e "  ${DIM}────────────────────────────────${NC}"
    echo ""
}

print_success() {
    echo -e "  ${GREEN}✔${NC} $1"
}

print_error() {
    echo -e "  ${RED}✖${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "  ${DIM}$1${NC}"
}

# 带默认值的输入（支持 Ctrl+C 退出）
prompt_input() {
    local prompt_text=$1
    local default_value=$2
    local result_var=$3

    if [ -n "$default_value" ]; then
        echo -en "  ${prompt_text} ${DIM}[${default_value}]${NC}: "
    else
        echo -en "  ${prompt_text}: "
    fi
    read -r input
    if [ -z "$input" ]; then
        eval "$result_var='$default_value'"
    else
        eval "$result_var='$input'"
    fi
}

# 带密码掩码的输入
prompt_secret() {
    local prompt_text=$1
    local default_value=$2
    local result_var=$3

    if [ -n "$default_value" ]; then
        local masked="${default_value:0:6}****"
        echo -en "  ${prompt_text} ${DIM}[${masked}]${NC}: "
    else
        echo -en "  ${prompt_text}: "
    fi
    read -r input
    if [ -z "$input" ]; then
        eval "$result_var='$default_value'"
    else
        eval "$result_var='$input'"
    fi
}

# 是否确认（Y/n）
confirm() {
    local prompt_text=$1
    local default=${2:-Y}
    if [ "$default" = "Y" ]; then
        echo -en "  ${prompt_text} ${DIM}[Y/n]${NC}: "
    else
        echo -en "  ${prompt_text} ${DIM}[y/N]${NC}: "
    fi
    read -r answer
    answer=${answer:-$default}
    [[ "$answer" =~ ^[Yy] ]]
}

# URL 格式验证
validate_url() {
    local url=$1
    if [[ "$url" =~ ^https?://.+/v1$ ]]; then
        return 0
    else
        return 1
    fi
}

# 捕获 Ctrl+C
trap 'echo ""; echo ""; print_warn "安装已取消。你的配置已保存到 .env，下次运行 ./setup.sh 可继续。"; echo ""; exit 0' INT

# ==================== 环境检查 ====================

print_header
echo -e "  ${BOLD}正在检查环境...${NC}"
echo ""

# 检查 Docker
if ! command -v docker &>/dev/null; then
    print_error "未检测到 Docker"
    echo ""
    echo -e "  请先安装 Docker Desktop："
    echo -e "  ${CYAN}https://docker.com/get-started${NC}"
    echo ""
    echo -e "  macOS: 下载 .dmg → 拖入 Applications → 启动"
    echo -e "  Windows: 下载 .exe → 勾选 WSL 2 → 安装重启"
    echo -e "  Linux: curl -fsSL https://get.docker.com | sh"
    echo ""
    exit 1
fi
print_success "Docker $(docker --version 2>/dev/null | sed 's/.*version //' | sed 's/,.*//')"

# 检查 Docker Compose
if ! docker compose version &>/dev/null; then
    print_error "未检测到 Docker Compose V2"
    echo ""
    echo -e "  请更新 Docker Desktop 到最新版本"
    echo ""
    exit 1
fi
print_success "Docker Compose $(docker compose version 2>/dev/null | sed 's/.*v//')"

# 检查 Docker 是否在运行
if ! docker info &>/dev/null; then
    print_error "Docker 未在运行，请先启动 Docker Desktop"
    exit 1
fi
print_success "Docker 正在运行"

echo ""
sleep 1

# ==================== 加载已有配置 ====================

NEWAPI_BASE_URL=""
NEWAPI_API_KEY=""
PRIMARY_MODEL="claude-sonnet-4-20260514"
THINKING_MODEL="claude-opus-4-20260514"
SETUP_WECHAT="no"
BRAVE_API_KEY=""
USER_NAME=""
USER_LANG="中文"
TZ="Asia/Shanghai"

if [ -f .env ]; then
    source .env 2>/dev/null
    print_info "检测到已有配置，将作为默认值使用。"
    echo ""
    sleep 1
fi

# ==================== Step 1: 模型供应商 ====================

step1() {
    print_header
    print_step 1 "模型供应商配置（New-api）"

    print_info "New-api 是开源 API 管理平台，提供统一入口访问多家模型。"
    print_info "如果还没有 New-api，请参考教程部署：https://github.com/Calcium-Ion/new-api"
    echo ""

    while true; do
        prompt_input "New-api Base URL (必须以 /v1 结尾)" "$NEWAPI_BASE_URL" NEWAPI_BASE_URL

        if [ -z "$NEWAPI_BASE_URL" ]; then
            print_error "Base URL 不能为空"
            continue
        fi

        if ! validate_url "$NEWAPI_BASE_URL"; then
            print_error "URL 格式不正确，必须以 http(s):// 开头，以 /v1 结尾"
            print_info "示例: https://your-server.com/v1"
            echo ""
            NEWAPI_BASE_URL=""
            continue
        fi

        print_success "URL 格式正确"
        break
    done

    echo ""

    while true; do
        prompt_secret "New-api API Key (sk-开头)" "$NEWAPI_API_KEY" NEWAPI_API_KEY

        if [ -z "$NEWAPI_API_KEY" ]; then
            print_error "API Key 不能为空"
            continue
        fi

        if [ ${#NEWAPI_API_KEY} -lt 8 ]; then
            print_error "API Key 太短，请检查是否复制完整"
            NEWAPI_API_KEY=""
            continue
        fi

        print_success "API Key 已记录"
        break
    done

    echo ""
    echo -e "  ${DIM}按 Enter 继续，输入 r 重新填写${NC}"
    read -r action
    if [[ "$action" = "r" || "$action" = "R" ]]; then
        NEWAPI_BASE_URL=""
        NEWAPI_API_KEY=""
        step1
        return
    fi
}

# ==================== Step 2: 模型选择 ====================

step2() {
    print_header
    print_step 2 "模型选择"

    print_info "primary = 日常对话（建议 Sonnet，性价比最高）"
    print_info "thinking = 深度推理（建议 Opus，复杂任务自动切换）"
    echo ""

    echo -e "  ${BOLD}推荐模型组合：${NC}"
    echo -e "  ${GREEN}1)${NC} claude-sonnet-4 + claude-opus-4 ${DIM}（推荐，平衡性价比）${NC}"
    echo -e "  ${GREEN}2)${NC} claude-sonnet-4 + claude-sonnet-4 ${DIM}（纯省钱模式）${NC}"
    echo -e "  ${GREEN}3)${NC} 自定义模型名称"
    echo ""
    echo -en "  选择 ${DIM}[1]${NC}: "
    read -r model_choice
    model_choice=${model_choice:-1}

    case $model_choice in
        1)
            PRIMARY_MODEL="claude-sonnet-4-20260514"
            THINKING_MODEL="claude-opus-4-20260514"
            ;;
        2)
            PRIMARY_MODEL="claude-sonnet-4-20260514"
            THINKING_MODEL="claude-sonnet-4-20260514"
            ;;
        3)
            prompt_input "Primary 模型名称" "$PRIMARY_MODEL" PRIMARY_MODEL
            prompt_input "Thinking 模型名称" "$THINKING_MODEL" THINKING_MODEL
            ;;
        *)
            PRIMARY_MODEL="claude-sonnet-4-20260514"
            THINKING_MODEL="claude-opus-4-20260514"
            ;;
    esac

    echo ""
    print_success "Primary: $PRIMARY_MODEL"
    print_success "Thinking: $THINKING_MODEL"

    echo ""
    echo -e "  ${DIM}按 Enter 继续，输入 b 返回上一步${NC}"
    read -r action
    if [[ "$action" = "b" || "$action" = "B" ]]; then
        step1
        step2
        return
    fi
}

# ==================== Step 3: 可选功能 ====================

step3() {
    print_header
    print_step 3 "可选功能配置"

    # 微信
    echo -e "  ${BOLD}📱 个人微信接入（官方 ClawBot 插件）${NC}"
    print_info "通过微信 iOS 8.0.70+ 内置 ClawBot 插件接入，官方支持，安全不封号。"
    print_info "前置条件：微信 → 设置 → 插件 中能看到 ClawBot 入口"
    echo ""

    if confirm "  是否配置微信？"; then
        SETUP_WECHAT="yes"
        print_success "将在安装阶段配置微信插件（需扫码授权）"
    else
        SETUP_WECHAT="no"
        print_info "已跳过微信配置（后续可手动安装）"
    fi

    echo ""

    # Brave Search
    echo -e "  ${BOLD}🔍 联网搜索（Brave Search API）${NC}"
    print_info "让 AI 像用 Google 一样搜索互联网，获取实时信息。"
    echo ""
    echo -e "  ${DIM}为什么推荐 Brave Search？${NC}"
    echo -e "    • 免费额度 2000 次/月，个人使用足够"
    echo -e "    • 隐私友好，不追踪用户"
    echo -e "    • OpenClaw 官方内置支持，配置简单"
    echo ""
    echo -e "  ${DIM}不配置会怎样？${NC}"
    echo -e "    • AI 无法主动搜索关键词（如「今天 BTC 价格」）"
    echo -e "    • 但仍可通过 web-browser Skill 访问指定网页（已自动安装）"
    echo -e "    • 你给 AI 一个链接，它可以直接读取内容"
    echo ""
    echo -e "  ${DIM}获取方式：https://brave.com/search/api/ → 注册 → Free 计划${NC}"
    echo ""

    if confirm "  是否配置搜索？" "N"; then
        echo ""
        prompt_secret "Brave Search API Key (BSA_开头)" "$BRAVE_API_KEY" BRAVE_API_KEY
        if [ -n "$BRAVE_API_KEY" ]; then
            print_success "搜索 Key 已记录"
        else
            print_info "已跳过搜索配置"
        fi
    else
        BRAVE_API_KEY=""
        print_info "已跳过（web-browser Skill 仍可访问网页，后续可在 .env 中添加）"
    fi

    echo ""
    echo -e "  ${DIM}按 Enter 继续，输入 b 返回上一步${NC}"
    read -r action
    if [[ "$action" = "b" || "$action" = "B" ]]; then
        step2
        step3
        return
    fi
}

# ==================== Step 4: 用户信息 ====================

step4() {
    print_header
    print_step 4 "用户信息（用于生成 User.md）"

    print_info "这些信息帮助 AI 更好地了解你，生成更贴合你习惯的回复。"
    echo ""

    prompt_input "你的名字" "$USER_NAME" USER_NAME
    prompt_input "主要语言" "$USER_LANG" USER_LANG
    prompt_input "时区" "$TZ" TZ

    echo ""
    print_success "用户信息已记录"

    echo ""
    echo -e "  ${DIM}按 Enter 继续，输入 b 返回上一步${NC}"
    read -r action
    if [[ "$action" = "b" || "$action" = "B" ]]; then
        step3
        step4
        return
    fi
}

# ==================== Step 5: 确认并安装 ====================

step5() {
    print_header
    print_step 5 "确认配置"

    echo -e "  ${BOLD}请确认以下配置信息：${NC}"
    echo ""
    echo -e "  ${CYAN}模型供应商${NC}"
    echo -e "    Base URL:  ${BOLD}$NEWAPI_BASE_URL${NC}"
    echo -e "    API Key:   ${BOLD}${NEWAPI_API_KEY:0:6}****${NC}"
    echo ""
    echo -e "  ${CYAN}模型路由${NC}"
    echo -e "    Primary:   ${BOLD}$PRIMARY_MODEL${NC}"
    echo -e "    Thinking:  ${BOLD}$THINKING_MODEL${NC}"
    echo ""
    echo -e "  ${CYAN}可选功能${NC}"
    if [ "$SETUP_WECHAT" = "yes" ]; then
        echo -e "    微信:      ${GREEN}✔ 安装后扫码授权${NC}"
    else
        echo -e "    微信:      ${DIM}未配置${NC}"
    fi
    if [ -n "$BRAVE_API_KEY" ]; then
        echo -e "    搜索:      ${GREEN}✔ 已配置${NC}"
    else
        echo -e "    搜索:      ${DIM}未配置${NC}"
    fi
    echo ""
    echo -e "  ${CYAN}用户信息${NC}"
    echo -e "    名字:      ${BOLD}$USER_NAME${NC}"
    echo -e "    语言:      ${BOLD}$USER_LANG${NC}"
    echo -e "    时区:      ${BOLD}$TZ${NC}"
    echo ""
    echo -e "  ${DIM}────────────────────────────────${NC}"
    echo ""
    echo -e "  操作选项："
    echo -e "    ${GREEN}Enter${NC}  确认并开始安装"
    echo -e "    ${YELLOW}1${NC}      修改模型供应商"
    echo -e "    ${YELLOW}2${NC}      修改模型选择"
    echo -e "    ${YELLOW}3${NC}      修改可选功能"
    echo -e "    ${YELLOW}4${NC}      修改用户信息"
    echo -e "    ${RED}q${NC}      保存配置但不安装"
    echo ""
    echo -en "  你的选择: "
    read -r action

    case $action in
        1) step1; step5; return ;;
        2) step2; step5; return ;;
        3) step3; step5; return ;;
        4) step4; step5; return ;;
        q|Q)
            save_env
            echo ""
            print_success "配置已保存到 .env"
            print_info "下次运行 ./setup.sh 可继续安装。"
            echo ""
            exit 0
            ;;
        *)
            # 继续安装
            ;;
    esac
}

# ==================== 保存 .env ====================

save_env() {
    cat > .env << EOF
# OpenClaw 配置（由 setup.sh 生成于 $(date '+%Y-%m-%d %H:%M:%S')）

NEWAPI_BASE_URL=$NEWAPI_BASE_URL
NEWAPI_API_KEY=$NEWAPI_API_KEY
PRIMARY_MODEL=$PRIMARY_MODEL
THINKING_MODEL=$THINKING_MODEL
SETUP_WECHAT=$SETUP_WECHAT
BRAVE_API_KEY=$BRAVE_API_KEY
TZ=$TZ
OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN

USER_NAME=$USER_NAME
USER_LANG=$USER_LANG
EOF
}

# ==================== 执行安装 ====================

do_install() {
    print_header
    echo -e "  ${BOLD}🚀 开始安装...${NC}"
    echo ""

    # 生成固定 Gateway Token（仅首次安装时生成一次）
    if [ -z "$OPENCLAW_GATEWAY_TOKEN" ]; then
        OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 24 2>/dev/null || head -c 48 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 48)
        export OPENCLAW_GATEWAY_TOKEN
    fi

    # 保存 .env
    save_env
    print_success "配置已保存到 .env"

    # Step 1: 目录
    echo ""
    echo -e "  ${BLUE}[1/7]${NC} 创建目录结构..."
    mkdir -p config workspace skills
    print_success "config/ workspace/ skills/ 已创建"

    # Step 2: Docker
    echo ""
    echo -e "  ${BLUE}[2/7]${NC} 拉取镜像并启动容器（首次约 2-5 分钟）..."
    echo -en "    ${DIM}下载中"
    if docker compose pull 2>&1 | while read -r line; do echo -en "."; done; then
        echo -e " 完成${NC}"
    else
        echo -e " 失败${NC}"
        print_error "镜像拉取失败，请检查网络连接"
        print_info "手动重试：docker compose pull"
        exit 1
    fi

    echo -en "    ${DIM}启动容器..."
    if docker compose up -d 2>/dev/null; then
        echo -e " 完成${NC}"
    else
        echo ""
        print_error "Docker 容器启动失败"
        print_info "请检查：docker compose logs"
        exit 1
    fi

    # 验证容器是否真的在运行
    sleep 2
    if ! docker ps --format '{{.Names}}' | grep -q openclaw-main; then
        echo ""
        print_error "容器 openclaw-main 未成功启动"
        print_info "请检查：docker compose logs"
        exit 1
    fi
    print_success "容器 openclaw-main 已启动"

    # 等待
    echo ""
    echo -en "  ${DIM}等待容器就绪"
    for i in 1 2 3 4 5; do
        sleep 1
        echo -en "."
    done
    echo -e "${NC}"

    # Step 3: openclaw.json（写入宿主 config/ 目录，自动映射到容器内）
    echo ""
    echo -e "  ${BLUE}[3/7]${NC} 生成模型配置 (openclaw.json)..."
    cat > config/openclaw.json << JSONEOF
{
  "models": {
    "providers": {
      "new-api": {
        "baseUrl": "${NEWAPI_BASE_URL}",
        "apiKey": "${NEWAPI_API_KEY}",
        "api": "anthropic-messages",
        "models": [
          {
            "id": "${PRIMARY_MODEL}",
            "name": "Primary Model"
          },
          {
            "id": "${THINKING_MODEL}",
            "name": "Thinking Model",
            "reasoning": true
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": "new-api/${PRIMARY_MODEL}"
    }
  }
}
JSONEOF
    print_success "openclaw.json 已写入"

    # Step 4: MD 模板
    echo ""
    echo -e "  ${BLUE}[4/7]${NC} 复制 MD 模板..."
    if ls templates/*.md 1>/dev/null 2>&1; then
        for f in templates/*.md; do
            fname=$(basename "$f")
            cp "$f" workspace/"$fname" && \
                print_success "$fname" || \
                print_warn "$fname 复制失败"
        done
    else
        print_warn "templates/ 目录无 MD 文件，跳过"
    fi

    # 生成 User.md
    cat > workspace/USER.md << USEREOF
# User

## 基本信息
- 名字：${USER_NAME}
- 时区：${TZ}
- 语言：${USER_LANG}

## 工作习惯
- 偏好简洁直接的沟通
- 需要时提供完整命令
USEREOF
    print_success "USER.md（根据你的信息生成）"

    # Step 5: Skills
    echo ""
    echo -e "  ${BLUE}[5/7]${NC} 安装核心 Skills..."
    print_info "网页浏览和文件读写为内置功能，无需安装"
    local skills=("brave-search:联网搜索" "summarize:长文摘要" "openclaw-cost-tracker:成本追踪")
    for item in "${skills[@]}"; do
        local skill_name="${item%%:*}"
        local skill_desc="${item##*:}"
        docker exec openclaw-main openclaw skills install "$skill_name" --force 2>/dev/null && \
            print_success "$skill_desc ($skill_name)" || \
            print_warn "$skill_desc ($skill_name) 安装跳过"
    done
    print_success "网页浏览（内置 Headless Browser）"
    print_success "文件读写（内置 File System）"

    # Step 6: 微信
    echo ""
    echo -e "  ${BLUE}[6/7]${NC} 配置通讯频道..."
    if [ "$SETUP_WECHAT" = "yes" ]; then
        # 使用 openclaw 原生命令安装微信插件
        docker exec openclaw-main openclaw plugins install "@tencent-weixin/openclaw-weixin" --force 2>/dev/null && \
            print_success "微信插件 openclaw-weixin 已安装" || \
            print_warn "微信插件安装失败（可稍后手动安装）"
        # 启用插件
        docker exec openclaw-main openclaw config set plugins.entries.openclaw-weixin.enabled true 2>/dev/null || true
        print_warn "微信需扫码授权（见下方说明）"
    else
        print_info "微信未配置，已跳过"
    fi

    # Step 7: 重启容器（确保新配置和插件生效）
    echo ""
    echo -e "  ${BLUE}[7/7]${NC} 重启容器 (应用配置和插件)..."
    docker restart openclaw-main >/dev/null
    sleep 5
    print_success "容器已重启"

    # ==================== 完成 ====================
    echo ""
    echo -e "  ${DIM}════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}${BOLD}✅ 安装完成！${NC}"
    echo ""
    echo -e "  ${BOLD}管理面板${NC}:  ${CYAN}http://localhost:18789/?token=${OPENCLAW_GATEWAY_TOKEN}${NC}"
    echo -e "  ${DIM}（点击以上链接即可自动登录，无需输入密码）${NC}"
    echo -e "  ${BOLD}查看日志${NC}:  docker compose logs -f"
    echo -e "  ${BOLD}进入容器${NC}:  docker exec -it openclaw-main bash"
    echo -e "  ${BOLD}查看状态${NC}:  在对话中输入 /status"

    if [ "$SETUP_WECHAT" = "yes" ]; then
        echo ""
        echo -e "  ${YELLOW}${BOLD}📱 微信扫码授权${NC}:"
        echo -e "    docker exec -it openclaw-main openclaw channels login --channel openclaw-weixin"
        echo -e "    ${DIM}# 终端会显示二维码${NC}"
        echo -e "    ${DIM}# 手机：微信 → 设置 → 插件 → ClawBot → 扫码 → 确认${NC}"
    fi

    echo ""
    echo -e "  ${DIM}配置文件: $(pwd)/.env${NC}"
    echo -e "  ${DIM}重新配置: 编辑 .env 后运行 ./setup.sh${NC}"
    echo ""
}

# ==================== 主流程 ====================

step1
step2
step3
step4
step5
do_install
