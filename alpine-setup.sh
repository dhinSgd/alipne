#!/bin/sh
# alpine-setup - SlimAlpine 系统快速配置工具
# 提供交互式菜单方便用户配置常用项

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SSHD_CONFIG="/etc/ssh/sshd_config"
CHRONY_CONFIG="/etc/chrony/chrony.conf"

# 必须 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "${RED}错误: 此脚本需要 root 权限运行${NC}"
    echo "请使用: sudo $0 或切换到 root 用户"
    exit 1
fi

print_header() {
    clear
    echo "${CYAN}=========================================="
    echo "  SlimAlpine 系统快速配置工具"
    echo "==========================================${NC}"
    echo ""
}

print_menu() {
    echo "${BLUE}请选择要执行的操作:${NC}"
    echo ""
    echo "  ${GREEN}1${NC}) 修改 root SSH 密码"
    echo "  ${GREEN}2${NC}) 修改 SSH 端口"
    echo "  ${GREEN}3${NC}) 设置时区并同步时间"
    echo "  ${GREEN}4${NC}) 一键完成所有配置"
    echo "  ${GREEN}5${NC}) 查看当前配置"
    echo ""
    echo "  ${GREEN}0${NC}) 退出"
    echo ""
}

# ==========================================
# 功能 1: 修改 root SSH 密码
# ==========================================
change_root_password() {
    print_header
    echo "${YELLOW}>>> 修改 root SSH 密码${NC}"
    echo ""
    echo "提示: 密码至少 8 位，建议包含大小写字母、数字和特殊字符"
    echo ""

    if passwd root; then
        echo ""
        echo "${GREEN}✓ root 密码修改成功${NC}"
    else
        echo ""
        echo "${RED}✗ root 密码修改失败${NC}"
        return 1
    fi

    echo ""
    read -p "按回车键继续..." dummy
}

# ==========================================
# 功能 2: 修改 SSH 端口
# ==========================================
change_ssh_port() {
    print_header
    echo "${YELLOW}>>> 修改 SSH 端口${NC}"
    echo ""

    # 显示当前端口
    CURRENT_PORT=$(grep -E "^Port " "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    if [ -z "$CURRENT_PORT" ]; then
        CURRENT_PORT="22 (默认)"
    fi
    echo "当前 SSH 端口: ${CYAN}$CURRENT_PORT${NC}"
    echo ""
    echo "${YELLOW}注意事项:${NC}"
    echo "  - 端口范围: 1-65535"
    echo "  - 建议使用 1024 以上的端口（避免与系统服务冲突）"
    echo "  - 避免使用常见端口（如 80, 443, 3306 等）"
    echo "  - 推荐使用 2222, 22222, 50000 等"
    echo ""

    read -p "请输入新的 SSH 端口（输入 0 取消）: " NEW_PORT

    # 验证输入
    if [ "$NEW_PORT" = "0" ] || [ -z "$NEW_PORT" ]; then
        echo "${YELLOW}已取消${NC}"
        read -p "按回车键继续..." dummy
        return 0
    fi

    if ! echo "$NEW_PORT" | grep -qE "^[0-9]+$"; then
        echo "${RED}✗ 错误: 端口必须为数字${NC}"
        read -p "按回车键继续..." dummy
        return 1
    fi

    if [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
        echo "${RED}✗ 错误: 端口必须在 1-65535 之间${NC}"
        read -p "按回车键继续..." dummy
        return 1
    fi

    # 检查端口是否被占用
    if netstat -tln 2>/dev/null | grep -qE ":$NEW_PORT[[:space:]]"; then
        echo "${RED}✗ 错误: 端口 $NEW_PORT 已被其他程序占用${NC}"
        read -p "按回车键继续..." dummy
        return 1
    fi

    # 备份配置文件
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    echo "${GREEN}✓ 已备份原配置${NC}"

    # 修改端口
    if grep -qE "^Port " "$SSHD_CONFIG"; then
        sed -i "s/^Port .*/Port $NEW_PORT/" "$SSHD_CONFIG"
    elif grep -qE "^#Port " "$SSHD_CONFIG"; then
        sed -i "s/^#Port .*/Port $NEW_PORT/" "$SSHD_CONFIG"
    else
        echo "Port $NEW_PORT" >> "$SSHD_CONFIG"
    fi

    # 验证配置
    if ! sshd -t 2>/dev/null; then
        echo "${RED}✗ SSH 配置验证失败，正在回滚...${NC}"
        cp "${SSHD_CONFIG}.bak."* "$SSHD_CONFIG" 2>/dev/null || true
        read -p "按回车键继续..." dummy
        return 1
    fi

    # 重启 sshd 服务
    echo "${BLUE}正在重启 sshd 服务...${NC}"
    if rc-service sshd restart; then
        echo ""
        echo "${GREEN}✓ SSH 端口已修改为: $NEW_PORT${NC}"
        echo ""
        echo "${YELLOW}重要提示:${NC}"
        echo "  下次 SSH 登录请使用新端口:"
        echo "  ${CYAN}ssh -p $NEW_PORT root@<服务器IP>${NC}"
        echo ""
        echo "${YELLOW}⚠ 请勿断开当前 SSH 连接，先开新窗口测试新端口可连接！${NC}"
    else
        echo "${RED}✗ sshd 重启失败${NC}"
        return 1
    fi

    echo ""
    read -p "按回车键继续..." dummy
}

# ==========================================
# 功能 3: 设置时区并同步时间
# ==========================================
setup_timezone() {
    print_header
    echo "${YELLOW}>>> 设置时区并同步时间${NC}"
    echo ""

    # 显示当前时区
    CURRENT_TZ=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || echo "未设置")
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S %Z')
    echo "当前时区: ${CYAN}$CURRENT_TZ${NC}"
    echo "当前时间: ${CYAN}$CURRENT_TIME${NC}"
    echo ""

    echo "${BLUE}常用时区:${NC}"
    echo "  ${GREEN}1${NC}) Asia/Shanghai      - 中国大陆 (UTC+8) ${YELLOW}[推荐]${NC}"
    echo "  ${GREEN}2${NC}) Asia/Hong_Kong     - 中国香港 (UTC+8)"
    echo "  ${GREEN}3${NC}) Asia/Tokyo         - 日本东京 (UTC+9)"
    echo "  ${GREEN}4${NC}) Asia/Singapore     - 新加坡 (UTC+8)"
    echo "  ${GREEN}5${NC}) America/New_York   - 美国东部 (UTC-5/-4)"
    echo "  ${GREEN}6${NC}) America/Los_Angeles- 美国西部 (UTC-8/-7)"
    echo "  ${GREEN}7${NC}) Europe/London      - 英国伦敦 (UTC+0/+1)"
    echo "  ${GREEN}8${NC}) UTC                - 协调世界时"
    echo "  ${GREEN}9${NC}) 自定义输入"
    echo "  ${GREEN}0${NC}) 跳过时区设置"
    echo ""

    read -p "请选择时区 [默认 1]: " TZ_CHOICE
    TZ_CHOICE=${TZ_CHOICE:-1}

    case "$TZ_CHOICE" in
        1) TIMEZONE="Asia/Shanghai" ;;
        2) TIMEZONE="Asia/Hong_Kong" ;;
        3) TIMEZONE="Asia/Tokyo" ;;
        4) TIMEZONE="Asia/Singapore" ;;
        5) TIMEZONE="America/New_York" ;;
        6) TIMEZONE="America/Los_Angeles" ;;
        7) TIMEZONE="Europe/London" ;;
        8) TIMEZONE="UTC" ;;
        9)
            read -p "请输入时区 (如 Asia/Shanghai): " TIMEZONE
            ;;
        0)
            echo "${YELLOW}跳过时区设置${NC}"
            TIMEZONE=""
            ;;
        *)
            echo "${RED}无效选择，使用默认 Asia/Shanghai${NC}"
            TIMEZONE="Asia/Shanghai"
            ;;
    esac

    # 设置时区
    if [ -n "$TIMEZONE" ]; then
        # 安装 tzdata（如果未安装）
        if [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
            echo "${BLUE}正在安装时区数据 tzdata...${NC}"
            apk add --no-cache tzdata > /dev/null 2>&1 || {
                echo "${RED}✗ tzdata 安装失败，请检查网络${NC}"
                read -p "按回车键继续..." dummy
                return 1
            }
        fi

        if [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
            cp "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
            echo "$TIMEZONE" > /etc/timezone
            echo "${GREEN}✓ 时区已设置为: $TIMEZONE${NC}"
        else
            echo "${RED}✗ 时区 $TIMEZONE 不存在${NC}"
            read -p "按回车键继续..." dummy
            return 1
        fi
    fi

    echo ""
    echo "${BLUE}>>> 配置 NTP 时间同步${NC}"
    echo ""
    echo "选择 NTP 服务器:"
    echo "  ${GREEN}1${NC}) 阿里云 NTP (ntp.aliyun.com) ${YELLOW}[国内推荐]${NC}"
    echo "  ${GREEN}2${NC}) 腾讯云 NTP (ntp.tencent.com)"
    echo "  ${GREEN}3${NC}) 国家授时中心 (ntp.ntsc.ac.cn)"
    echo "  ${GREEN}4${NC}) Cloudflare NTP (time.cloudflare.com) ${YELLOW}[国际推荐]${NC}"
    echo "  ${GREEN}5${NC}) Google NTP (time.google.com)"
    echo "  ${GREEN}6${NC}) 默认 pool.ntp.org"
    echo ""

    read -p "请选择 NTP 服务器 [默认 1]: " NTP_CHOICE
    NTP_CHOICE=${NTP_CHOICE:-1}

    case "$NTP_CHOICE" in
        1)
            NTP_SERVERS="ntp.aliyun.com ntp1.aliyun.com ntp2.aliyun.com"
            ;;
        2)
            NTP_SERVERS="ntp.tencent.com ntp1.tencent.com ntp2.tencent.com"
            ;;
        3)
            NTP_SERVERS="ntp.ntsc.ac.cn cn.pool.ntp.org"
            ;;
        4)
            NTP_SERVERS="time.cloudflare.com time.nist.gov"
            ;;
        5)
            NTP_SERVERS="time.google.com time1.google.com"
            ;;
        6)
            NTP_SERVERS="pool.ntp.org 0.pool.ntp.org 1.pool.ntp.org"
            ;;
        *)
            NTP_SERVERS="ntp.aliyun.com ntp1.aliyun.com"
            ;;
    esac

    # 检查 chrony 是否安装
    if ! command -v chronyd > /dev/null 2>&1; then
        echo "${BLUE}正在安装 chrony...${NC}"
        apk add --no-cache chrony > /dev/null 2>&1 || {
            echo "${RED}✗ chrony 安装失败${NC}"
            read -p "按回车键继续..." dummy
            return 1
        }
    fi

    # 备份原配置
    if [ -f "$CHRONY_CONFIG" ]; then
        cp "$CHRONY_CONFIG" "${CHRONY_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    fi

    # 写入新配置
    {
        echo "# Chrony 配置 - 由 alpine-setup 生成"
        echo "# 时间: $(date)"
        echo ""
        for server in $NTP_SERVERS; do
            echo "server $server iburst"
        done
        echo ""
        echo "driftfile /var/lib/chrony/chrony.drift"
        echo "makestep 1.0 3"
        echo "rtcsync"
        echo "logdir /var/log/chrony"
    } > "$CHRONY_CONFIG"

    echo "${GREEN}✓ chrony 配置已更新${NC}"

    # 启用并启动 chronyd
    rc-update add chronyd default > /dev/null 2>&1 || true

    if rc-service chronyd restart; then
        echo "${GREEN}✓ chronyd 服务已启动${NC}"
    else
        echo "${RED}✗ chronyd 启动失败${NC}"
        read -p "按回车键继续..." dummy
        return 1
    fi

    # 立即同步一次时间
    echo ""
    echo "${BLUE}正在同步时间...${NC}"
    sleep 2
    chronyc makestep > /dev/null 2>&1 || true
    sleep 2

    echo ""
    echo "${GREEN}✓ 时间同步配置完成${NC}"
    echo ""
    echo "当前时间: ${CYAN}$(date '+%Y-%m-%d %H:%M:%S %Z')${NC}"
    echo ""
    echo "${BLUE}NTP 同步状态:${NC}"
    chronyc tracking 2>/dev/null | head -8 || echo "(等待初始同步)"

    echo ""
    read -p "按回车键继续..." dummy
}

# ==========================================
# 功能 4: 一键完成所有配置
# ==========================================
setup_all() {
    print_header
    echo "${YELLOW}>>> 一键完成所有配置${NC}"
    echo ""
    echo "将依次执行以下操作:"
    echo "  1. 修改 root SSH 密码"
    echo "  2. 修改 SSH 端口"
    echo "  3. 设置时区并同步时间"
    echo ""
    read -p "是否继续？[y/N]: " CONFIRM

    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "${YELLOW}已取消${NC}"
        read -p "按回车键继续..." dummy
        return 0
    fi

    change_root_password
    change_ssh_port
    setup_timezone

    print_header
    echo "${GREEN}✓ 所有配置已完成！${NC}"
    echo ""
    show_status
    read -p "按回车键继续..." dummy
}

# ==========================================
# 功能 5: 查看当前配置
# ==========================================
show_status() {
    print_header
    echo "${YELLOW}>>> 当前系统配置${NC}"
    echo ""

    echo "${BLUE}[ 系统信息 ]${NC}"
    echo "  主机名: $(hostname)"
    echo "  系统:   $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo "  内核:   $(uname -r)"
    echo "  架构:   $(uname -m)"
    echo ""

    echo "${BLUE}[ 时间信息 ]${NC}"
    echo "  当前时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    CURRENT_TZ=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || echo "未设置")
    echo "  当前时区: $CURRENT_TZ"
    if rc-service chronyd status > /dev/null 2>&1; then
        echo "  时间同步: ${GREEN}已启用 (chronyd)${NC}"
    else
        echo "  时间同步: ${RED}未启用${NC}"
    fi
    echo ""

    echo "${BLUE}[ SSH 配置 ]${NC}"
    SSH_PORT=$(grep -E "^Port " "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    SSH_PORT=${SSH_PORT:-22}
    echo "  SSH 端口:     $SSH_PORT"

    ROOT_LOGIN=$(grep -E "^PermitRootLogin " "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    ROOT_LOGIN=${ROOT_LOGIN:-yes}
    echo "  允许 root:    $ROOT_LOGIN"

    PASS_AUTH=$(grep -E "^PasswordAuthentication " "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    PASS_AUTH=${PASS_AUTH:-yes}
    echo "  密码登录:     $PASS_AUTH"

    KEY_AUTH=$(grep -E "^PubkeyAuthentication " "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    KEY_AUTH=${KEY_AUTH:-yes}
    echo "  密钥登录:     $KEY_AUTH"

    if rc-service sshd status > /dev/null 2>&1; then
        echo "  sshd 状态:    ${GREEN}运行中${NC}"
    else
        echo "  sshd 状态:    ${RED}未运行${NC}"
    fi
    echo ""

    echo "${BLUE}[ 网络信息 ]${NC}"
    IP_ADDR=$(ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -1)
    echo "  IP 地址: ${IP_ADDR:-未获取}"
    echo "  DNS:    $(grep nameserver /etc/resolv.conf | head -2 | awk '{print $2}' | tr '\n' ' ')"
    echo ""

    echo "${BLUE}[ 系统资源 ]${NC}"
    MEM_INFO=$(free -h | grep Mem | awk '{print "总内存: "$2"  已用: "$3"  可用: "$7}')
    echo "  $MEM_INFO"
    DISK_INFO=$(df -h / | tail -1 | awk '{print "根分区: "$2"  已用: "$3"  可用: "$4"  使用率: "$5}')
    echo "  $DISK_INFO"
    if [ -b /dev/zram0 ]; then
        ZRAM_INFO=$(swapon -s | grep zram0 | awk '{print "zram swap: 已启用 ("$3" KB)"}')
        echo "  $ZRAM_INFO"
    fi
    echo ""

    read -p "按回车键继续..." dummy
}

# ==========================================
# 主循环
# ==========================================
main() {
    while true; do
        print_header
        print_menu
        read -p "请输入选项 [0-5]: " CHOICE

        case "$CHOICE" in
            1) change_root_password ;;
            2) change_ssh_port ;;
            3) setup_timezone ;;
            4) setup_all ;;
            5) show_status ;;
            0)
                echo ""
                echo "${GREEN}再见！${NC}"
                exit 0
                ;;
            *)
                echo "${RED}无效选项，请重新选择${NC}"
                sleep 1
                ;;
        esac
    done
}

main
