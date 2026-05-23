#!/bin/bash
# verify.sh - 系统验证脚本
# 在构建的系统中运行此脚本以验证所有功能

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

check() {
    local name="$1"
    local command="$2"

    echo -n "检查 $name... "
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC}"
        ((FAIL++))
        return 1
    fi
}

check_output() {
    local name="$1"
    local command="$2"
    local expected="$3"

    echo -n "检查 $name... "
    output=$(eval "$command" 2>/dev/null || echo "")
    if echo "$output" | grep -q "$expected"; then
        echo -e "${GREEN}✓${NC}"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} (期望: $expected, 实际: $output)"
        ((FAIL++))
        return 1
    fi
}

echo "=========================================="
echo "  alipne 系统验证"
echo "=========================================="
echo ""

echo "==> 基础系统"
check "操作系统" "grep -q Alpine /etc/os-release"
check "内核版本" "uname -r | grep -q virt"
check "主机名" "hostname | grep -q SlimAlpine"
check "时区" "[ -L /etc/localtime ]"

echo ""
echo "==> 文件系统"
check "btrfs 根分区" "mount | grep -q 'on / type btrfs'"
check "btrfs 压缩" "mount | grep / | grep -q 'compress=zstd'"
check "noatime 选项" "mount | grep / | grep -q 'noatime'"
check "EFI 分区" "mount | grep -q '/boot/efi type vfat'"
check "@ 子卷" "btrfs subvolume list / | grep -q '@$'"
check "@home 子卷" "btrfs subvolume list / | grep -q '@home'"
check "@var_log 子卷" "btrfs subvolume list / | grep -q '@var_log'"

echo ""
echo "==> 内存管理"
check "zram 设备" "[ -b /dev/zram0 ]"
check "zram swap" "swapon -s | grep -q zram0"
check_output "swappiness" "cat /proc/sys/vm/swappiness" "100"
check "zstd 压缩" "zramctl | grep -q zstd"

echo ""
echo "==> 网络"
check "网络接口" "ip link show eth0"
check "IP 地址" "ip addr show eth0 | grep -q 'inet '"
check "DNS 解析" "ping -c 1 1.1.1.1"
check "DNS 配置" "grep -q '1.1.1.1' /etc/resolv.conf"
check "外网连接" "ping -c 1 google.com"

echo ""
echo "==> 服务"
check "OpenRC" "[ -x /sbin/openrc ]"
check "sshd" "rc-service sshd status"
check "chronyd" "rc-service chronyd status"
check "crond" "rc-service crond status"
check "qemu-guest-agent" "rc-service qemu-guest-agent status"
check "cloud-init" "[ -x /usr/bin/cloud-init ]"

echo ""
echo "==> 系统资源"
ROOT_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$ROOT_USAGE" -lt 20 ]; then
    echo -e "检查根分区使用率... ${GREEN}✓${NC} ($ROOT_USAGE%)"
    ((PASS++))
else
    echo -e "检查根分区使用率... ${YELLOW}!${NC} ($ROOT_USAGE%, 期望 < 20%)"
    ((FAIL++))
fi

FREE_MEM=$(free -m | grep Mem | awk '{print $4}')
if [ "$FREE_MEM" -gt 300 ]; then
    echo -e "检查可用内存... ${GREEN}✓${NC} (${FREE_MEM}MB)"
    ((PASS++))
else
    echo -e "检查可用内存... ${YELLOW}!${NC} (${FREE_MEM}MB, 期望 > 300MB)"
    ((FAIL++))
fi

echo ""
echo "==> 详细信息"
echo ""
echo "系统信息:"
cat /etc/os-release | grep PRETTY_NAME
uname -r

echo ""
echo "内存使用:"
free -h

echo ""
echo "磁盘使用:"
df -h / /boot/efi

echo ""
echo "Swap 信息:"
swapon -s

echo ""
echo "btrfs 信息:"
btrfs filesystem usage / 2>/dev/null || btrfs filesystem df /

echo ""
echo "运行的服务:"
rc-status --servicelist

echo ""
echo "=========================================="
echo "  验证结果"
echo "=========================================="
echo -e "通过: ${GREEN}$PASS${NC}"
echo -e "失败: ${RED}$FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ 所有检查通过！${NC}"
    exit 0
else
    echo -e "${RED}✗ 部分检查失败${NC}"
    exit 1
fi
