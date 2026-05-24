#!/bin/sh
# alpine-optimize.sh - 在官方 Alpine 系统上进行极简优化
# 适用于已安装的 Alpine Linux 系统（阿里云 ECS）
#
# 功能：
# 1. 配置 zram swap (384MB)
# 2. 清理不需要的内核模块
# 3. 系统精简（删除文档、locale 等）
# 4. 优化系统参数
# 5. 配置基础服务

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 必须 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "${RED}错误: 此脚本需要 root 权限运行${NC}"
    exit 1
fi

print_header() {
    echo ""
    echo "${CYAN}=========================================="
    echo "  $1"
    echo "==========================================${NC}"
    echo ""
}

print_step() {
    echo "${BLUE}>>> $1${NC}"
}

print_success() {
    echo "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo "${RED}✗ $1${NC}"
}

# 显示系统信息
show_system_info() {
    print_header "当前系统信息"

    echo "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "内核版本: $(uname -r)"
    echo "架构:     $(uname -m)"
    echo ""
    echo "内存信息:"
    free -h
    echo ""
    echo "磁盘信息:"
    df -h /
    echo ""
}

# 备份重要文件
backup_files() {
    print_step "备份重要配置文件"

    BACKUP_DIR="/root/alpine-optimize-backup-$(date +%Y%m%d%H%M%S)"
    mkdir -p "$BACKUP_DIR"

    # 备份关键配置
    [ -f /etc/fstab ] && cp /etc/fstab "$BACKUP_DIR/"
    [ -f /etc/sysctl.conf ] && cp /etc/sysctl.conf "$BACKUP_DIR/"
    [ -d /etc/sysctl.d ] && cp -r /etc/sysctl.d "$BACKUP_DIR/"

    print_success "配置已备份到: $BACKUP_DIR"
}

# 安装必要的软件包
install_packages() {
    print_step "安装必要的软件包"

    apk update
    apk add --no-cache \
        zram-init \
        chrony \
        nano \
        curl \
        wget \
        htop \
        ncdu

    print_success "软件包安装完成"
}

# 配置 zram swap
setup_zram() {
    print_step "配置 zram swap (384MB)"

    # 创建配置文件
    cat > /etc/conf.d/zram-init <<'EOF'
# zram-init 配置
# 创建 384MB zram swap 设备

num_devices=1

# 设备 0: swap
load0="swap"
type0="swap"
flag0="zram"
size0=384
maxs0=2
algo0="zstd"
labl0="zram-swap"
uuid0=""
notr0=""
mntp0=""
opts0=""
opte0=""
EOF

    # 配置内核参数
    cat > /etc/sysctl.d/99-zram.conf <<'EOF'
# zram 内存管理优化
# 适度使用 zram swap（比硬盘快 100 倍）

vm.swappiness=80
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=1
vm.dirty_ratio=5
vm.page-cluster=0
EOF

    # 应用内核参数
    sysctl -p /etc/sysctl.d/99-zram.conf

    # 启用 zram-init 服务
    rc-update add zram-init boot
    rc-service zram-init start || print_warning "zram-init 启动失败，可能需要重启"

    print_success "zram 配置完成"

    # 显示 swap 状态
    echo ""
    echo "Swap 状态:"
    swapon -s || true
}

# 清理内核模块（黑名单模式）
cleanup_kernel_modules() {
    print_step "清理不需要的内核模块"

    KERNEL_VERSION=$(uname -r)
    MODULES_DIR="/lib/modules/$KERNEL_VERSION"

    if [ ! -d "$MODULES_DIR" ]; then
        print_warning "内核模块目录不存在，跳过"
        return
    fi

    print_warning "这将删除以下类型的内核模块："
    echo "  - 显卡驱动（GPU, fbdev）"
    echo "  - 声卡驱动"
    echo "  - 蓝牙"
    echo "  - 无线网卡"
    echo "  - 多媒体设备"
    echo "  - 输入设备（键盘/鼠标）"
    echo ""

    read -p "是否继续？[y/N]: " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        print_warning "跳过内核模块清理"
        return
    fi

    # 计算清理前大小
    BEFORE_SIZE=$(du -sm "$MODULES_DIR" | awk '{print $1}')

    # 删除不需要的模块
    DELETED=0

    # 显卡驱动
    if [ -d "$MODULES_DIR/kernel/drivers/gpu" ]; then
        rm -rf "$MODULES_DIR/kernel/drivers/gpu"
        DELETED=$((DELETED + 1))
    fi

    # 声卡驱动
    if [ -d "$MODULES_DIR/kernel/sound" ]; then
        rm -rf "$MODULES_DIR/kernel/sound"
        DELETED=$((DELETED + 1))
    fi

    # 蓝牙
    if [ -d "$MODULES_DIR/kernel/drivers/bluetooth" ]; then
        rm -rf "$MODULES_DIR/kernel/drivers/bluetooth"
        DELETED=$((DELETED + 1))
    fi
    if [ -d "$MODULES_DIR/kernel/net/bluetooth" ]; then
        rm -rf "$MODULES_DIR/kernel/net/bluetooth"
        DELETED=$((DELETED + 1))
    fi

    # 无线网卡
    if [ -d "$MODULES_DIR/kernel/drivers/net/wireless" ]; then
        rm -rf "$MODULES_DIR/kernel/drivers/net/wireless"
        DELETED=$((DELETED + 1))
    fi

    # 多媒体设备
    if [ -d "$MODULES_DIR/kernel/drivers/media" ]; then
        rm -rf "$MODULES_DIR/kernel/drivers/media"
        DELETED=$((DELETED + 1))
    fi

    # 输入设备
    for dir in keyboard mouse touchscreen joystick; do
        if [ -d "$MODULES_DIR/kernel/drivers/input/$dir" ]; then
            rm -rf "$MODULES_DIR/kernel/drivers/input/$dir"
            DELETED=$((DELETED + 1))
        fi
    done

    # HID 设备
    if [ -d "$MODULES_DIR/kernel/drivers/hid" ]; then
        rm -rf "$MODULES_DIR/kernel/drivers/hid"
        DELETED=$((DELETED + 1))
    fi

    # 删除 virtio_balloon（固定内存不需要）
    find "$MODULES_DIR" -name "virtio_balloon.ko*" -delete 2>/dev/null || true

    # 重新生成模块依赖
    if [ $DELETED -gt 0 ]; then
        print_step "重新生成模块依赖..."
        depmod -a || print_warning "depmod 警告（可忽略）"

        # 计算清理后大小
        AFTER_SIZE=$(du -sm "$MODULES_DIR" | awk '{print $1}')
        SAVED=$((BEFORE_SIZE - AFTER_SIZE))

        print_success "已删除 $DELETED 类模块，节省 ${SAVED}MB 空间"
    else
        print_warning "未找到需要删除的模块"
    fi
}

# 系统精简
cleanup_system() {
    print_step "系统精简"

    # 删除文档
    rm -rf /usr/share/man/* 2>/dev/null || true
    rm -rf /usr/share/doc/* 2>/dev/null || true
    rm -rf /usr/share/info/* 2>/dev/null || true

    # 删除本地化文件（保留 en_US）
    find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} \; 2>/dev/null || true
    rm -rf /usr/share/i18n/locales/* 2>/dev/null || true

    # 清理 apk 缓存
    rm -rf /var/cache/apk/* 2>/dev/null || true
    rm -rf /etc/apk/cache/* 2>/dev/null || true

    # 清理临时文件
    rm -rf /tmp/* 2>/dev/null || true
    rm -rf /var/tmp/* 2>/dev/null || true

    # 清理日志（保留最近的）
    find /var/log -type f -name "*.log" -mtime +7 -delete 2>/dev/null || true

    print_success "系统精简完成"
}

# 优化系统服务
optimize_services() {
    print_step "优化系统服务"

    # 禁用不需要的服务
    for service in acpid klogd; do
        if rc-service $service status >/dev/null 2>&1; then
            rc-update del $service default 2>/dev/null || true
            rc-service $service stop 2>/dev/null || true
            print_success "已禁用服务: $service"
        fi
    done

    # 确保必要服务启用
    for service in chronyd crond sshd; do
        if ! rc-service $service status >/dev/null 2>&1; then
            rc-update add $service default 2>/dev/null || true
            print_success "已启用服务: $service"
        fi
    done
}

# 配置时区和时间同步
setup_timezone() {
    print_step "配置时区和时间同步"

    # 设置时区为 Asia/Shanghai
    if [ ! -f /usr/share/zoneinfo/Asia/Shanghai ]; then
        apk add --no-cache tzdata
    fi

    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo "Asia/Shanghai" > /etc/timezone

    # 配置 chrony
    cat > /etc/chrony/chrony.conf <<'EOF'
# Chrony 配置 - 阿里云 NTP
server ntp.aliyun.com iburst
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst

driftfile /var/lib/chrony/chrony.drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

    rc-service chronyd restart

    print_success "时区已设置为 Asia/Shanghai"
}

# 显示优化结果
show_results() {
    print_header "优化完成"

    echo "${GREEN}系统优化已完成！${NC}"
    echo ""
    echo "优化内容："
    echo "  ✓ zram swap (384MB, zstd 压缩)"
    echo "  ✓ 内核模块精简"
    echo "  ✓ 系统文件清理"
    echo "  ✓ 服务优化"
    echo "  ✓ 时区和时间同步"
    echo ""

    echo "当前系统状态："
    echo ""
    echo "内存使用:"
    free -h
    echo ""
    echo "磁盘使用:"
    df -h /
    echo ""
    echo "Swap 状态:"
    swapon -s
    echo ""

    echo "${YELLOW}建议操作：${NC}"
    echo "  1. 重启系统使所有更改生效: reboot"
    echo "  2. 修改 root 密码: passwd"
    echo "  3. 配置 SSH 密钥认证"
    echo "  4. 配置防火墙（iptables）"
    echo ""
    echo "${CYAN}配置脚本已下载到当前目录：${NC}"
    echo "  wget https://raw.githubusercontent.com/dhinSgd/alipne/main/alpine-setup.sh"
    echo "  chmod +x alpine-setup.sh"
    echo "  ./alpine-setup.sh"
    echo ""
}

# 主函数
main() {
    print_header "Alpine Linux 系统优化脚本"

    echo "此脚本将对系统进行以下优化："
    echo "  1. 配置 zram swap (384MB)"
    echo "  2. 清理不需要的内核模块"
    echo "  3. 系统精简（删除文档、locale 等）"
    echo "  4. 优化系统参数和服务"
    echo "  5. 配置时区和时间同步"
    echo ""
    echo "${YELLOW}警告: 此操作会删除一些系统文件，建议先备份重要数据${NC}"
    echo ""

    read -p "是否继续？[y/N]: " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "已取消"
        exit 0
    fi

    show_system_info
    backup_files
    install_packages
    setup_zram
    cleanup_kernel_modules
    cleanup_system
    optimize_services
    setup_timezone
    show_results

    echo ""
    read -p "是否立即重启系统？[y/N]: " REBOOT
    if [ "$REBOOT" = "y" ] || [ "$REBOOT" = "Y" ]; then
        echo "系统将在 5 秒后重启..."
        sleep 5
        reboot
    fi
}

main
