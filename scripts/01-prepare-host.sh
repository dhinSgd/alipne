#!/bin/bash
# 01-prepare-host.sh - 准备宿主机构建环境

set -e

echo "==> 检查宿主机环境..."

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
    echo "错误: 需要 root 权限运行构建脚本"
    echo "请使用: sudo make prepare"
    exit 1
fi

# 检查操作系统
if [ ! -f /etc/os-release ]; then
    echo "错误: 无法识别操作系统"
    exit 1
fi

source /etc/os-release
if [ "$ID" != "ubuntu" ] && [ "$ID" != "debian" ]; then
    echo "警告: 此脚本针对 Ubuntu/Debian 优化，其他发行版可能需要调整"
fi

echo "==> 安装构建依赖..."

# 更新包列表
apt-get update -qq

# 安装必需的包
apt-get install -y \
    qemu-utils \
    qemu-system-x86 \
    btrfs-progs \
    dosfstools \
    e2fsprogs \
    rsync \
    parted \
    grub-efi-amd64-bin \
    ovmf \
    wget \
    curl \
    kpartx \
    util-linux

echo "==> 检查 OVMF 固件..."
if [ ! -f /usr/share/OVMF/OVMF_CODE.fd ]; then
    echo "警告: OVMF 固件未找到，QEMU UEFI 测试可能失败"
    echo "尝试安装: apt-get install ovmf"
fi

echo "==> 创建输出目录..."
mkdir -p /workspace/alipne/output

echo "==> 下载 alpine-make-vm-image（如果需要）..."
if [ ! -f /usr/local/bin/alpine-make-vm-image ]; then
    wget -O /usr/local/bin/alpine-make-vm-image \
        https://raw.githubusercontent.com/alpinelinux/alpine-make-vm-image/v0.12.0/alpine-make-vm-image
    chmod +x /usr/local/bin/alpine-make-vm-image
    echo "✓ alpine-make-vm-image 已安装"
else
    echo "✓ alpine-make-vm-image 已存在"
fi

echo ""
echo "✓ 宿主机环境准备完成"
echo ""
echo "系统信息:"
echo "  OS: $PRETTY_NAME"
echo "  Kernel: $(uname -r)"
echo "  QEMU: $(qemu-system-x86_64 --version | head -1)"
echo "  Parted: $(parted --version | head -1)"
echo ""
