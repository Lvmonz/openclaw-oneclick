#!/bin/bash
# ============================================
# 🦞 OpenClaw 一键安装脚本（交互式）
# 版本: 1.0.0
# ============================================

# 注意：不使用 set -e，关键步骤手动检查错误

# 防止 Ctrl+Z (SIGTSTP) 将脚本挂起导致 docker 锁死，捕获后直接清理所有相关子进程并强制终止
trap 'echo -e "\n\033[0;31m检测到 Ctrl+Z 操作，已强行清理后台残留环境进程以防止死锁。\033[0m"; pkill -P $$; kill -9 $$' SIGTSTP

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

# API 连通性预检
precheck_api() {
    local base_url=$1
    local api_key=$2
    local provider=$3

    echo ""
    echo -en "  ${DIM}正在验证 API 连通性..."

    local http_code
    if [ "$provider" = "anthropic" ]; then
        # Anthropic 使用 x-api-key header
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "x-api-key: $api_key" \
            -H "anthropic-version: 2023-06-01" \
            "${base_url}/models" --max-time 10 2>/dev/null)
    else
        # OpenAI 兼容格式
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: Bearer $api_key" \
            "${base_url}/models" --max-time 10 2>/dev/null)
    fi

    if [ "$http_code" = "000" ]; then
        echo -e "${NC}"
        print_warn "无法连接到 ${base_url}，请检查网络"
        print_info "安装将继续，但如果 API 配置有误，容器启动后对话会报错"
        return 1
    elif [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
        echo -e "${NC}"
        print_error "API Key 验证失败 (HTTP $http_code)，请检查 Key 是否正确"
        if confirm "  仍然继续安装？" "N"; then
            return 0
        else
            return 2
        fi
    elif [[ "$http_code" =~ ^2 ]]; then
        echo -e " ✔${NC}"
        print_success "API 连通性验证通过"
        return 0
    else
        echo -e "${NC}"
        print_warn "API 返回 HTTP $http_code，可能正常也可能有问题"
        print_info "安装将继续"
        return 0
    fi
}

# 构造 docker compose 命令（根据是否启用浏览器动态选择 compose 文件）
compose_cmd() {
    if [ "$SHARE_CHROME" = "yes" ]; then
        docker compose -f docker-compose.yml -f docker-compose.browser.yml "$@"
    else
        docker compose "$@"
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

PROVIDER_NAME=""
NEWAPI_BASE_URL=""
NEWAPI_API_KEY=""
API_FORMAT="openai-completions"
PRIMARY_MODEL=""
THINKING_MODEL=""
SETUP_WECHAT="no"
SHARE_CHROME="no"
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
# 参考社区脚本: github.com/miaoxworld/OpenClawInstaller (setup_ai_provider)
# 参考社区脚本: github.com/ProjectAILiberation/PocketClaw (change-api.sh)

step1() {
    print_header
    print_step 1 "模型供应商选择"

    echo -e "  ${BOLD}选择你的 API 供应商：${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} 🟣 Anthropic（Claude 官方直连）"
    echo -e "  ${GREEN}2)${NC} 🟢 OpenAI（GPT 官方直连）"
    echo -e "  ${GREEN}3)${NC} 🔄 OpenRouter（多模型聚合网关）"
    echo -e "  ${GREEN}4)${NC} 🔵 DeepSeek（国产推荐）"
    echo -e "  ${GREEN}5)${NC} 🌙 Kimi / Moonshot"
    echo -e "  ${GREEN}6)${NC} ⚡ 硅基流动 SiliconFlow"
    echo -e "  ${GREEN}7)${NC} 🇨🇳 智谱 GLM"
    echo -e "  ${GREEN}8)${NC} 🔴 Google Gemini"
    echo -e "  ${GREEN}9)${NC} 𝕏 xAI Grok"
    echo -e "  ${GREEN}10)${NC} 🔧 自定义（New-api / One-api / 自建代理）"
    echo ""
    echo -en "  选择 ${DIM}[1]${NC}: "
    read -r provider_choice
    provider_choice=${provider_choice:-1}

    case $provider_choice in
        1)
            PROVIDER_NAME="anthropic"
            NEWAPI_BASE_URL="https://api.anthropic.com/v1"
            API_FORMAT="anthropic-messages"
            print_success "已选择 Anthropic（Claude 官方）"
            ;;
        2)
            PROVIDER_NAME="openai"
            NEWAPI_BASE_URL="https://api.openai.com/v1"
            API_FORMAT="openai-completions"
            print_success "已选择 OpenAI（GPT 官方）"
            ;;
        3)
            PROVIDER_NAME="openrouter"
            NEWAPI_BASE_URL="https://openrouter.ai/api/v1"
            API_FORMAT="openai-completions"
            print_success "已选择 OpenRouter"
            ;;
        4)
            # 参考: miaoxworld/OpenClawInstaller position 20 + PocketClaw change-api.sh
            PROVIDER_NAME="deepseek"
            NEWAPI_BASE_URL="https://api.deepseek.com"
            API_FORMAT="openai-completions"
            print_success "已选择 DeepSeek"
            ;;
        5)
            # 参考: miaoxworld/OpenClawInstaller position 20 (Kimi/Moonshot)
            PROVIDER_NAME="kimi"
            echo ""
            echo -e "  ${BOLD}选择区域：${NC}"
            echo -e "  ${GREEN}1)${NC} 国际版 (api.moonshot.ai)"
            echo -e "  ${GREEN}2)${NC} 国内版 (api.moonshot.cn)"
            echo -en "  选择 ${DIM}[1]${NC}: "
            read -r kimi_region
            kimi_region=${kimi_region:-1}
            if [ "$kimi_region" = "2" ]; then
                NEWAPI_BASE_URL="https://api.moonshot.cn/v1"
            else
                NEWAPI_BASE_URL="https://api.moonshot.ai/v1"
            fi
            API_FORMAT="openai-completions"
            print_success "已选择 Kimi / Moonshot"
            ;;
        6)
            # 参考: 3445286649/openclaw-deploy quick_config_siliconflow + PocketClaw
            PROVIDER_NAME="siliconflow"
            NEWAPI_BASE_URL="https://api.siliconflow.cn/v1"
            API_FORMAT="openai-completions"
            print_success "已选择 硅基流动 SiliconFlow"
            ;;
        7)
            # 参考: PocketClaw change-api.sh (zhipu)
            PROVIDER_NAME="zhipu"
            NEWAPI_BASE_URL="https://open.bigmodel.cn/api/paas/v4"
            API_FORMAT="openai-completions"
            print_success "已选择 智谱 GLM"
            ;;
        8)
            # 参考: miaoxworld/OpenClawInstaller position 20 (google)
            PROVIDER_NAME="google"
            NEWAPI_BASE_URL=""
            API_FORMAT=""
            print_success "已选择 Google Gemini"
            ;;
        9)
            # 参考: miaoxworld/OpenClawInstaller position 21 (xai)
            PROVIDER_NAME="xai"
            NEWAPI_BASE_URL=""
            API_FORMAT=""
            print_success "已选择 xAI Grok"
            ;;
        10)
            PROVIDER_NAME="custom"
            echo ""
            while true; do
                prompt_input "自定义 Base URL (必须以 /v1 结尾)" "$NEWAPI_BASE_URL" NEWAPI_BASE_URL
                if [ -z "$NEWAPI_BASE_URL" ]; then
                    print_error "Base URL 不能为空"
                    continue
                fi
                if ! validate_url "$NEWAPI_BASE_URL"; then
                    print_error "URL 格式不正确，必须以 http(s):// 开头，以 /v1 结尾"
                    NEWAPI_BASE_URL=""
                    continue
                fi
                break
            done

            echo ""
            echo -e "  ${BOLD}API 协议格式：${NC}"
            echo -e "  ${GREEN}1)${NC} OpenAI 兼容 ${DIM}（大多数代理）${NC}"
            echo -e "  ${GREEN}2)${NC} Anthropic Messages ${DIM}（Claude 系列代理）${NC}"
            echo -en "  选择 ${DIM}[1]${NC}: "
            read -r fmt_choice
            fmt_choice=${fmt_choice:-1}
            if [ "$fmt_choice" = "2" ]; then
                API_FORMAT="anthropic-messages"
            else
                API_FORMAT="openai-completions"
            fi
            print_success "自定义供应商: $NEWAPI_BASE_URL ($API_FORMAT)"
            ;;
        *)
            PROVIDER_NAME="anthropic"
            NEWAPI_BASE_URL="https://api.anthropic.com/v1"
            API_FORMAT="anthropic-messages"
            print_success "已选择 Anthropic（Claude 官方）"
            ;;
    esac

    echo ""

    while true; do
        prompt_secret "API Key" "$NEWAPI_API_KEY" NEWAPI_API_KEY

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
    echo -e "  ${DIM}按 Enter 继续，输入 r 重新选择${NC}"
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

    print_info "primary = 日常对话，thinking = 深度推理（复杂任务自动切换）"
    echo ""

    echo -e "  ${BOLD}推荐模型组合（${PROVIDER_NAME}）：${NC}"

    case "$PROVIDER_NAME" in
        anthropic)
            echo -e "  ${GREEN}1)${NC} claude-sonnet-4 + claude-opus-4 ${DIM}（推荐）${NC}"
            echo -e "  ${GREEN}2)${NC} claude-sonnet-4 + claude-sonnet-4 ${DIM}（省钱）${NC}"
            echo -e "  ${GREEN}3)${NC} 自定义模型名称"
            echo ""
            echo -en "  选择 ${DIM}[1]${NC}: "
            read -r model_choice
            model_choice=${model_choice:-1}
            case $model_choice in
                1) PRIMARY_MODEL="claude-sonnet-4-20260514"; THINKING_MODEL="claude-opus-4-20260514" ;;
                2) PRIMARY_MODEL="claude-sonnet-4-20260514"; THINKING_MODEL="claude-sonnet-4-20260514" ;;
                3) prompt_input "Primary 模型" "$PRIMARY_MODEL" PRIMARY_MODEL
                   prompt_input "Thinking 模型" "$THINKING_MODEL" THINKING_MODEL ;;
                *) PRIMARY_MODEL="claude-sonnet-4-20260514"; THINKING_MODEL="claude-opus-4-20260514" ;;
            esac
            ;;
        openai)
            echo -e "  ${GREEN}1)${NC} gpt-4o + o3 ${DIM}（推荐）${NC}"
            echo -e "  ${GREEN}2)${NC} gpt-4o + gpt-4o ${DIM}（省钱）${NC}"
            echo -e "  ${GREEN}3)${NC} 自定义模型名称"
            echo ""
            echo -en "  选择 ${DIM}[1]${NC}: "
            read -r model_choice
            model_choice=${model_choice:-1}
            case $model_choice in
                1) PRIMARY_MODEL="gpt-4o"; THINKING_MODEL="o3" ;;
                2) PRIMARY_MODEL="gpt-4o"; THINKING_MODEL="gpt-4o" ;;
                3) prompt_input "Primary 模型" "$PRIMARY_MODEL" PRIMARY_MODEL
                   prompt_input "Thinking 模型" "$THINKING_MODEL" THINKING_MODEL ;;
                *) PRIMARY_MODEL="gpt-4o"; THINKING_MODEL="o3" ;;
            esac
            ;;
        deepseek)
            echo -e "  ${GREEN}1)${NC} deepseek-chat + deepseek-reasoner ${DIM}（推荐）${NC}"
            echo -e "  ${GREEN}2)${NC} deepseek-chat + deepseek-chat ${DIM}（省钱）${NC}"
            echo -e "  ${GREEN}3)${NC} 自定义模型名称"
            echo ""
            echo -en "  选择 ${DIM}[1]${NC}: "
            read -r model_choice
            model_choice=${model_choice:-1}
            case $model_choice in
                1) PRIMARY_MODEL="deepseek-chat"; THINKING_MODEL="deepseek-reasoner" ;;
                2) PRIMARY_MODEL="deepseek-chat"; THINKING_MODEL="deepseek-chat" ;;
                3) prompt_input "Primary 模型" "$PRIMARY_MODEL" PRIMARY_MODEL
                   prompt_input "Thinking 模型" "$THINKING_MODEL" THINKING_MODEL ;;
                *) PRIMARY_MODEL="deepseek-chat"; THINKING_MODEL="deepseek-reasoner" ;;
            esac
            ;;
        siliconflow)
            echo -e "  ${GREEN}1)${NC} Qwen/Qwen3-235B-A22B + deepseek-ai/DeepSeek-R1 ${DIM}（推荐）${NC}"
            echo -e "  ${GREEN}2)${NC} deepseek-ai/DeepSeek-V3 + deepseek-ai/DeepSeek-R1 ${DIM}（DeepSeek 组合）${NC}"
            echo -e "  ${GREEN}3)${NC} 自定义模型名称"
            echo ""
            echo -en "  选择 ${DIM}[1]${NC}: "
            read -r model_choice
            model_choice=${model_choice:-1}
            case $model_choice in
                1) PRIMARY_MODEL="Qwen/Qwen3-235B-A22B"; THINKING_MODEL="deepseek-ai/DeepSeek-R1" ;;
                2) PRIMARY_MODEL="deepseek-ai/DeepSeek-V3"; THINKING_MODEL="deepseek-ai/DeepSeek-R1" ;;
                3) prompt_input "Primary 模型" "$PRIMARY_MODEL" PRIMARY_MODEL
                   prompt_input "Thinking 模型" "$THINKING_MODEL" THINKING_MODEL ;;
                *) PRIMARY_MODEL="Qwen/Qwen3-235B-A22B"; THINKING_MODEL="deepseek-ai/DeepSeek-R1" ;;
            esac
            ;;
        openrouter)
            echo -e "  ${GREEN}1)${NC} deepseek/deepseek-chat-v3-0324 + deepseek/deepseek-r1 ${DIM}（推荐，免费额度可用）${NC}"
            echo -e "  ${GREEN}2)${NC} anthropic/claude-sonnet-4 + anthropic/claude-opus-4 ${DIM}（需充值，效果最好）${NC}"
            echo -e "  ${GREEN}3)${NC} openai/gpt-4o + openai/o3 ${DIM}（需充值）${NC}"
            echo -e "  ${GREEN}4)${NC} 自定义模型名称"
            echo ""
            print_warn "注意：OpenRouter 免费额度账户无法使用 Anthropic/OpenAI/Google 模型"
            print_info "如需使用 Claude/GPT，请先在 openrouter.ai 充值后选择对应项"
            echo ""
            echo -en "  选择 ${DIM}[1]${NC}: "
            read -r model_choice
            model_choice=${model_choice:-1}
            case $model_choice in
                1) PRIMARY_MODEL="deepseek/deepseek-chat-v3-0324"; THINKING_MODEL="deepseek/deepseek-r1" ;;
                2) PRIMARY_MODEL="anthropic/claude-sonnet-4"; THINKING_MODEL="anthropic/claude-opus-4" ;;
                3) PRIMARY_MODEL="openai/gpt-4o"; THINKING_MODEL="openai/o3" ;;
                4) prompt_input "Primary 模型" "$PRIMARY_MODEL" PRIMARY_MODEL
                   prompt_input "Thinking 模型" "$THINKING_MODEL" THINKING_MODEL ;;
                *) PRIMARY_MODEL="deepseek/deepseek-chat-v3-0324"; THINKING_MODEL="deepseek/deepseek-r1" ;;
            esac
            ;;
        kimi)
            # 参考: miaoxworld/OpenClawInstaller position 20
            echo -e "  ${GREEN}1)${NC} kimi-k2.5 + kimi-k2.5 ${DIM}（推荐，最新）${NC}"
            echo -e "  ${GREEN}2)${NC} moonshot-v1-128k + moonshot-v1-128k ${DIM}（经典）${NC}"
            echo -e "  ${GREEN}3)${NC} 自定义模型名称"
            echo ""
            echo -en "  选择 ${DIM}[1]${NC}: "
            read -r model_choice
            model_choice=${model_choice:-1}
            case $model_choice in
                1) PRIMARY_MODEL="kimi-k2.5"; THINKING_MODEL="kimi-k2.5" ;;
                2) PRIMARY_MODEL="moonshot-v1-128k"; THINKING_MODEL="moonshot-v1-128k" ;;
                3) prompt_input "Primary 模型" "$PRIMARY_MODEL" PRIMARY_MODEL
                   prompt_input "Thinking 模型" "$THINKING_MODEL" THINKING_MODEL ;;
                *) PRIMARY_MODEL="kimi-k2.5"; THINKING_MODEL="kimi-k2.5" ;;
            esac
            ;;
        zhipu)
            # 参考: PocketClaw change-api.sh (zhipu/zhipu-pro)
            echo -e "  ${GREEN}1)${NC} glm-4-plus + glm-4-plus ${DIM}（推荐）${NC}"
            echo -e "  ${GREEN}2)${NC} glm-4-flash + glm-4-plus ${DIM}（省钱）${NC}"
            echo -e "  ${GREEN}3)${NC} 自定义模型名称"
            echo ""
            echo -en "  选择 ${DIM}[1]${NC}: "
            read -r model_choice
            model_choice=${model_choice:-1}
            case $model_choice in
                1) PRIMARY_MODEL="glm-4-plus"; THINKING_MODEL="glm-4-plus" ;;
                2) PRIMARY_MODEL="glm-4-flash"; THINKING_MODEL="glm-4-plus" ;;
                3) prompt_input "Primary 模型" "$PRIMARY_MODEL" PRIMARY_MODEL
                   prompt_input "Thinking 模型" "$THINKING_MODEL" THINKING_MODEL ;;
                *) PRIMARY_MODEL="glm-4-plus"; THINKING_MODEL="glm-4-plus" ;;
            esac
            ;;
        google)
            # 参考: miaoxworld/OpenClawInstaller position 20
            echo -e "  ${GREEN}1)${NC} gemini-2.5-pro + gemini-2.5-pro ${DIM}（推荐）${NC}"
            echo -e "  ${GREEN}2)${NC} gemini-2.5-flash + gemini-2.5-pro ${DIM}（省钱）${NC}"
            echo -e "  ${GREEN}3)${NC} 自定义模型名称"
            echo ""
            echo -en "  选择 ${DIM}[1]${NC}: "
            read -r model_choice
            model_choice=${model_choice:-1}
            case $model_choice in
                1) PRIMARY_MODEL="gemini-2.5-pro"; THINKING_MODEL="gemini-2.5-pro" ;;
                2) PRIMARY_MODEL="gemini-2.5-flash"; THINKING_MODEL="gemini-2.5-pro" ;;
                3) prompt_input "Primary 模型" "$PRIMARY_MODEL" PRIMARY_MODEL
                   prompt_input "Thinking 模型" "$THINKING_MODEL" THINKING_MODEL ;;
                *) PRIMARY_MODEL="gemini-2.5-pro"; THINKING_MODEL="gemini-2.5-pro" ;;
            esac
            ;;
        xai)
            # 参考: miaoxworld/OpenClawInstaller position 21 + PocketClaw
            echo -e "  ${GREEN}1)${NC} grok-3 + grok-3 ${DIM}（推荐）${NC}"
            echo -e "  ${GREEN}2)${NC} grok-3-mini + grok-3 ${DIM}（省钱）${NC}"
            echo -e "  ${GREEN}3)${NC} 自定义模型名称"
            echo ""
            echo -en "  选择 ${DIM}[1]${NC}: "
            read -r model_choice
            model_choice=${model_choice:-1}
            case $model_choice in
                1) PRIMARY_MODEL="grok-3"; THINKING_MODEL="grok-3" ;;
                2) PRIMARY_MODEL="grok-3-mini"; THINKING_MODEL="grok-3" ;;
                3) prompt_input "Primary 模型" "$PRIMARY_MODEL" PRIMARY_MODEL
                   prompt_input "Thinking 模型" "$THINKING_MODEL" THINKING_MODEL ;;
                *) PRIMARY_MODEL="grok-3"; THINKING_MODEL="grok-3" ;;
            esac
            ;;
        *)
            prompt_input "Primary 模型名称" "$PRIMARY_MODEL" PRIMARY_MODEL
            prompt_input "Thinking 模型名称" "$THINKING_MODEL" THINKING_MODEL
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

    # 浏览器功能 (Sidecar 架构)
    echo -e "  ${BOLD}🌐 浏览器功能 (独立 Sidecar 架构)${NC}"
    print_info "为提供极高稳定性和【持久化登录态】，将启动一个独立的 Chromium 容器。"
    print_info "核心优势：即便删除重装 OpenClaw 大脑，你在推特/微信等网页的登录状态也会永久保留！"
    echo ""
    print_warn "⚠️ 警告：独立的浏览器容器需要额外分配资源（建议预留 2GB 内存以防网页崩溃）。"
    echo ""

    if confirm "  是否启用独立浏览器 (Sidecar) 功能？"; then
        SHARE_CHROME="yes"
        print_success "将在安装阶段编排独立的浏览器容器"
    else
        SHARE_CHROME="no"
        print_info "已跳过浏览器功能"
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

PROVIDER_NAME=$PROVIDER_NAME
NEWAPI_BASE_URL=$NEWAPI_BASE_URL
NEWAPI_API_KEY=$NEWAPI_API_KEY
API_FORMAT=$API_FORMAT
PRIMARY_MODEL=$PRIMARY_MODEL
THINKING_MODEL=$THINKING_MODEL
SETUP_WECHAT=$SETUP_WECHAT
SHARE_CHROME=$SHARE_CHROME
BRAVE_API_KEY=$BRAVE_API_KEY
TZ=$TZ
OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN

USER_NAME=$USER_NAME
USER_LANG=$USER_LANG
EOF

    # 根据 SHARE_CHROME 设置 CDP 连接地址
    if [ "$SHARE_CHROME" = "yes" ]; then
        echo "CHROME_CDP_URL=ws://openclaw-browser:9222" >> .env
    else
        echo "CHROME_CDP_URL=" >> .env
    fi

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

    # Step 0: API 连通性预检
    precheck_api "$NEWAPI_BASE_URL" "$NEWAPI_API_KEY" "$PROVIDER_NAME"
    local precheck_result=$?
    if [ $precheck_result -eq 2 ]; then
        print_info "安装已取消，请修正 API Key 后重新运行 ./setup.sh"
        exit 0
    fi

    # Step 1: 准备配置文件（写到临时目录，稍后注入容器）
    echo ""
    echo -e "  ${BLUE}[1/7]${NC} 准备配置文件..."

    # 瞬间强杀旧容器，避免由于大模型死锁导致 docker compose down 傻等 10 秒超时
    compose_cmd kill 2>/dev/null || true
    compose_cmd down --remove-orphans -t 1 2>/dev/null || true

    # 仅在 --clean 参数时销毁数据卷（否则保留插件/skills）
    if [ "${CLEAN_INSTALL:-}" = "yes" ]; then
        docker volume rm "$(basename "$(pwd)")_openclaw-data" 2>/dev/null || true
        print_info "已清空核心数据卷（openclaw-data）"
        
        # 特别询问是否清空浏览器 profiles
        echo ""
        print_warn "⚠️ 发现浏览器持久化数据卷 (browser_profile)"
        print_warn "该数据卷保存了你所有网页（如 Twitter/Discord）的登录会话。"
        if confirm "  是否一并彻底销毁网页登录态？(选 N 可保留账户登录状态)"; then
            docker volume rm "$(basename "$(pwd)")_browser_profile" 2>/dev/null || true
            print_info "已清空浏览器会话状态"
        else
            print_success "已保留浏览器会话状态，重装后无需重新登录网页。"
        fi
        echo ""
    fi

    # 写入临时文件，后续 docker cp 注入容器
    local tmpdir
    tmpdir=$(mktemp -d)

    # 根据供应商类型生成 openclaw.json
    # 参考社区脚本: github.com/akhenda/ubuntu-openclaw-server (mortalezz-openclaw)
    # 参考社区脚本: github.com/drhayf/drofbot
    # 内置供应商使用 env 层注入 API Key + agents.defaults.model
    # 自定义供应商使用 models.providers 显式配置
    local json_content=""
    case "$PROVIDER_NAME" in
        openrouter)
            json_content=$(cat << JSONEOF
{
  "env": {
    "OPENROUTER_API_KEY": "${NEWAPI_API_KEY}"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/${PRIMARY_MODEL}",
        "fallbacks": [
          "openrouter/${THINKING_MODEL}"
        ]
      }
    }
  },
  "plugins": {
    "allow": ["openclaw-weixin"]
  }
}
JSONEOF
            )
            ;;
        anthropic)
            json_content=$(cat << JSONEOF
{
  "env": {
    "ANTHROPIC_API_KEY": "${NEWAPI_API_KEY}"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/${PRIMARY_MODEL}",
        "fallbacks": [
          "anthropic/${THINKING_MODEL}"
        ]
      }
    }
  },
  "plugins": {
    "allow": ["openclaw-weixin"]
  }
}
JSONEOF
            )
            ;;
        openai)
            json_content=$(cat << JSONEOF
{
  "env": {
    "OPENAI_API_KEY": "${NEWAPI_API_KEY}"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openai/${PRIMARY_MODEL}",
        "fallbacks": [
          "openai/${THINKING_MODEL}"
        ]
      }
    }
  },
  "plugins": {
    "allow": ["openclaw-weixin"]
  }
}
JSONEOF
            )
            ;;
        google)
            # 参考: miaoxworld/OpenClawInstaller position 20
            json_content=$(cat << JSONEOF
{
  "env": {
    "GEMINI_API_KEY": "${NEWAPI_API_KEY}"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "google/${PRIMARY_MODEL}",
        "fallbacks": [
          "google/${THINKING_MODEL}"
        ]
      }
    }
  },
  "plugins": {
    "allow": ["openclaw-weixin"]
  }
}
JSONEOF
            )
            ;;
        xai)
            # 参考: miaoxworld/OpenClawInstaller position 21
            json_content=$(cat << JSONEOF
{
  "env": {
    "XAI_API_KEY": "${NEWAPI_API_KEY}"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "xai/${PRIMARY_MODEL}",
        "fallbacks": [
          "xai/${THINKING_MODEL}"
        ]
      }
    }
  },
  "plugins": {
    "allow": ["openclaw-weixin"]
  }
}
JSONEOF
            )
            ;;
        *)
            # 自定义/其他供应商：使用 models.providers 显式配置（DeepSeek/硅基流动/Kimi 等）
            json_content=$(cat << JSONEOF
{
  "models": {
    "providers": {
      "${PROVIDER_NAME}": {
        "baseUrl": "${NEWAPI_BASE_URL}",
        "apiKey": "${NEWAPI_API_KEY}",
        "api": "${API_FORMAT}",
        "models": [
          {
            "id": "${PRIMARY_MODEL}",
            "name": "Primary Model"
          },
          {
            "id": "${THINKING_MODEL}",
            "name": "Thinking Model"
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": "${PROVIDER_NAME}/${PRIMARY_MODEL}"
    }
  },
  "plugins": {
    "allow": ["openclaw-weixin"]
  }
}
JSONEOF
            )
            ;;
    esac

    echo "$json_content" > "$tmpdir/openclaw.json"

    # USER.md
    cat > "$tmpdir/USER.md" << USEREOF
# User

## 基本信息
- 名字：${USER_NAME}
- 时区：${TZ}
- 语言：${USER_LANG}

## 工作习惯
- 偏好简洁直接的沟通
- 需要时提供完整命令
USEREOF

    # 复制 MD 模板到临时目录（SOUL.md 除外，下面单独生成）
    if ls templates/*.md 1>/dev/null 2>&1; then
        for f in templates/*.md; do
            local basename_f
            basename_f=$(basename "$f")
            if [ "$basename_f" != "SOUL.md" ]; then
                cp "$f" "$tmpdir/$basename_f" 2>/dev/null
            fi
        done
    fi

    # 动态生成 SOUL.md（根据配置注入环境信息）
    local chrome_section=""
    if [ "$SHARE_CHROME" = "yes" ]; then
        chrome_section="- **你有完整的浏览器控制权**：一个独立的 Sidecar 浏览器容器运行在 \`ws://openclaw-browser:9222\`
- 务必使用 Playwright 连接 CDP：\`playwright.chromium.connect_over_cdp(\"ws://openclaw-browser:9222\")\`
- 请注意：网页上下文（Cookies/Session）已通过 Volume 永久保存，当你接管 context 时，它已经带有用户的登录态。
- 长时间运行复杂网页可能导致内存爆炸。如果遇到 Timeout 或 CDP 断开，请先尝试刷新页面或重启页面流程。"
    else
        chrome_section="- 容器内未安装浏览器且未挂载 Sidecar，你只能通过 fetch/curl 获取网页内容（无 JS 渲染）
- 如需浏览器功能，请让用户运行 ./setup.sh 并启用独立浏览器"
    fi

    cat > "$tmpdir/SOUL.md" << SOULEOF
# Soul

## 角色定义
你是用户的高执行力私人助理。用户的需求就是最高优先级。

## 核心原则
- **先执行，再沟通**：收到指令立即行动，遇到无法解决的问题再沟通
- **不要反驳用户的需求**：用户让你做什么就做什么，除非涉及安全风险
- **不要主动提替代方案**：除非用户明确问"有没有更好的办法"
- **不要说教**：不解释"为什么你不应该这么做"，直接帮用户实现

## 运行环境
你运行在 Docker 容器中，而非用户的本地主机。需要注意：
- **工作目录**：你的文件在 /home/node/.openclaw/workspace/，这是容器内的独立空间
- **网络**：你可以发 HTTP 请求和调 API，但容器内没有浏览器二进制文件
- **宿主机文件系统**：你无法直接访问用户宿主机的文件，除非通过 Volume 挂载
- **Docker 命令**：你无法在容器内运行 docker 命令来管理自身
- **包管理**：你可以使用 npm、npx，但 apt-get 需要 root 权限，尽量避免

### 浏览器能力
容器内没有安装任何浏览器。你唯一能操控浏览器的方式是通过 CDP（Chrome DevTools Protocol）连接用户宿主机上的 Chrome。
${chrome_section}

## 沟通风格
- 简洁直接，不说废话
- 技术讨论用中文，代码和变量名用英文
- 回答问题先给结论，再给细节
- 长回答用标题分段，短回答直接说

## 输出规范
- 代码修改附带一句话说明
- 搜索前简要说明目的
- 给出可直接复制运行的完整命令

## 安全边界
- 不执行 rm -rf、格式化等不可逆危险操作
- 不主动泄露 API Key 或密码
- 遇到确实不确定的问题说「不确定」，但不要因为不确定就拒绝尝试
- **防死循环机制**：如果你在执行网页自动化代码（如 Playwright/Puppeteer）时多次遇到无法绕过的验证码、扫码、或页面报错，或者调用工具（如 `read` 等）连续失败 2 次以上，**必须立即停止重试**，总结失败原因并向用户寻求帮助。绝对禁止在没有用户明确回复的情况下无脑陷入死循环，给用户发送相同意思的“稍等，我再试一次”的无效重复消息。同时，注意每次调用 Tool 必须补全其规定的严格必选参数。
SOULEOF
    print_success "配置文件已准备"

    echo -e "  ${BLUE}[2/7]${NC} 拉取镜像（首次按需下载，约 2-5 分钟）..."
    echo -e "    ${DIM}以下是实时下载进度：${NC}"
    if compose_cmd pull; then
        print_success "镜像已就绪"
    else
        echo -e " 失败${NC}"
        print_error "镜像拉取失败，请检查网络连接"
        print_info "手动重试：docker compose pull"
        exit 1
    fi

    # 修复浏览器 Volume 权限（如果启用了浏览器）
    # browserless/chrome 容器以非 root 用运行（UID=999），而 Docker 默认创建的 Volume 为 root，可能导致写入权限报错
    if [ "$SHARE_CHROME" = "yes" ]; then
        echo -en "  ${DIM}初始化浏览器配置卷..."
        docker volume create "$(basename "$(pwd)")_browser_profile" >/dev/null 2>&1 || true
        docker run --rm -v "$(basename "$(pwd)")_browser_profile":/data alpine chown -R 999:999 /data 2>/dev/null || true
        echo -e " 完成${NC}"
    fi

    # Step 3: 启动容器（自动加载 config/ 中的配置）
    echo ""
    echo -e "  ${BLUE}[3/7]${NC} 启动容器..."
    echo -en "    ${DIM}启动中..."
    if compose_cmd up -d --remove-orphans 2>/dev/null; then
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

    # 等待容器就绪
    echo ""
    echo -en "  ${DIM}等待容器就绪"
    for i in 1 2 3 4 5; do
        sleep 1
        echo -en "."
    done
    echo -e "${NC}"

    # 注入配置文件到容器内 + 修复权限
    echo -en "  ${DIM}注入配置文件..."

    # 确保目录存在且权限正确（卷由 root 创建，需要 chown 给 node）
    docker exec -u root openclaw-main sh -c '
        mkdir -p /home/node/.openclaw/workspace /home/node/.openclaw/extensions /home/node/.openclaw/skills
        chown -R node:node /home/node/.openclaw
    ' 2>/dev/null

    docker cp "$tmpdir/openclaw.json" openclaw-main:/home/node/.openclaw/openclaw.json 2>/dev/null
    for f in "$tmpdir"/*.md; do
        [ -f "$f" ] && docker cp "$f" openclaw-main:/home/node/.openclaw/workspace/"$(basename "$f")" 2>/dev/null
    done

    # 复制 skills 模板到容器
    if [ -d "templates/skills" ]; then
        docker exec -u root openclaw-main mkdir -p /home/node/.openclaw/workspace/skills 2>/dev/null
        for f in templates/skills/*.md; do
            [ -f "$f" ] && docker cp "$f" openclaw-main:/home/node/.openclaw/workspace/skills/"$(basename "$f")" 2>/dev/null
        done
    fi

    # docker cp 后文件属主可能是 root，再次修正
    docker exec -u root openclaw-main chown -R node:node /home/node/.openclaw 2>/dev/null
    echo -e " 完成${NC}"

    # 清理临时目录
    rm -rf "$tmpdir"

    # 重启让配置生效
    docker restart openclaw-main >/dev/null 2>&1
    sleep 3

    # Step 4: Skills
    echo ""
    echo -e "  ${BLUE}[4/7]${NC} 安装核心 Skills..."
    print_info "网页浏览和文件读写为内置功能，无需安装"
    local skills=("brave-search:联网搜索" "summarize:长文摘要" "openclaw-cost-tracker:成本追踪")
    for item in "${skills[@]}"; do
        local skill_name="${item%%:*}"
        local skill_desc="${item##*:}"
        docker exec openclaw-main openclaw skills install "$skill_name" --force 2>/dev/null && \
            print_success "$skill_desc ($skill_name)" || \
            print_warn "$skill_desc ($skill_name) 安装跳过"
    done
    print_success "文件读写（内置 File System）"


    # Step 5: 微信
    echo ""
    echo -e "  ${BLUE}[5/7]${NC} 配置通讯频道..."
    if [ "$SETUP_WECHAT" = "yes" ]; then
        # 检查是否已安装
        if docker exec openclaw-main test -d /home/node/.openclaw/extensions/openclaw-weixin 2>/dev/null; then
            print_success "微信插件 openclaw-weixin 已存在，跳过安装"
        else
            echo -en "    ${DIM}安装微信插件（约 1-2 分钟）..."
            docker exec openclaw-main npx -y @tencent-weixin/openclaw-weixin-cli@latest install 2>/dev/null
            # npx 退出码可能非零（QR登录步骤失败），但插件实际已安装，所以检查目录而非退出码
            echo -e " ${NC}"
            if docker exec openclaw-main test -d /home/node/.openclaw/extensions/openclaw-weixin 2>/dev/null; then
                print_success "微信插件 openclaw-weixin 安装成功"
            else
                print_warn "微信插件安装失败（可手动：docker exec openclaw-main npx -y @tencent-weixin/openclaw-weixin-cli@latest install）"
            fi
        fi
        print_info "微信需扫码授权（见下方说明）"
    else
        print_info "微信未配置，已跳过"
    fi

    # Step 6: 清理
    echo ""
    echo -e "  ${BLUE}[6/7]${NC} 清理临时文件..."
    docker exec openclaw-main sh -c 'rm -f ~/.openclaw/*.clobbered.* ~/.openclaw/*.bak* 2>/dev/null' || true
    print_success "已清理"

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
    echo -e "  ${BOLD}CLI 对话${NC}:  docker exec -it openclaw-main openclaw agent -m \"你的问题\""
    echo -e "  ${BOLD}查看日志${NC}:  docker compose logs -f"
    echo -e "  ${BOLD}进入容器${NC}:  docker exec -it openclaw-main bash"
    echo -e "  ${BOLD}查看状态${NC}:  在对话中输入 /status"

    if [ "$SETUP_WECHAT" = "yes" ]; then
        echo ""
        echo -e "  ${YELLOW}${BOLD}📱 微信扫码授权（最后一步）${NC}:"
        echo -e "    docker exec -it openclaw-main openclaw channels login --channel openclaw-weixin"
        echo -e "    ${DIM}# 终端会显示二维码${NC}"
        echo -e "    ${DIM}# 手机：微信 → 设置 → 插件 → ClawBot → 扫码 → 确认${NC}"
        echo -e "    ${DIM}# 扫码完成后即可通过微信与 OpenClaw 对话${NC}"
    fi

    if [ "$SHARE_CHROME" = "yes" ]; then
        echo ""
        echo -e "  ${YELLOW}${BOLD}🌐 独立浏览器架构 (Sidecar)${NC}:"
        echo -e "    ${DIM}# openclaw-browser 容器已启动并在 9222 端口暴露 CDP。${NC}"
        echo -e "    ${DIM}# 浏览器登录态已持久化保存，任何重装都不会丢失账号登录！${NC}"
        echo -e "    ${DIM}# 在本机浏览器访问 http://127.0.0.1:9222 可实时围观 AI 视角的网页操作（Debug 神器）。${NC}"
    fi

    echo ""
    echo -e "  ${DIM}配置文件: $(pwd)/.env${NC}"
    echo -e "  ${DIM}重新配置: 编辑 .env 后运行 ./setup.sh${NC}"
    echo ""
}

# ==================== 主流程 ====================

# 解析参数
CLEAN_INSTALL=""
for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN_INSTALL="yes" ;;
    esac
done

step1
step2
step3
step4
step5
do_install
