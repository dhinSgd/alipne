#!/bin/bash
# 06-test-image.sh - QEMU 启动测试

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/output"

QCOW2_IMAGE="$OUTPUT_DIR/alipne.qcow2"

if [ ! -f "$QCOW2_IMAGE" ]; then
    echo "错误: 镜像文件不存在: $QCOW2_IMAGE"
    echo "请先运行: make pack"
    exit 1
fi

echo "==> 启动 QEMU 测试..."
echo ""
echo "镜像: $QCOW2_IMAGE"
echo "配置: 2 核 / 512 MB 内存"
echo "SSH 端口转发: localhost:2222 -> VM:22"
echo ""
echo "登录信息:"
echo "  用户名: root"
echo "  密码: alipne123"
echo ""
echo "SSH 登录命令:"
echo "  ssh -p 2222 root@localhost"
echo ""
echo "按 Ctrl+A 然后按 X 退出 QEMU"
echo ""
echo "启动中..."
sleep 2

# 检查 OVMF 固件
OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"
if [ ! -f "$OVMF_CODE" ]; then
    echo "警告: OVMF 固件未找到，尝试其他路径..."
    OVMF_CODE="/usr/share/qemu/OVMF_CODE.fd"
    if [ ! -f "$OVMF_CODE" ]; then
        echo "错误: 无法找到 OVMF 固件"
        echo "请安装: apt-get install ovmf"
        exit 1
    fi
fi

# 启动 QEMU
qemu-system-x86_64 \
    -enable-kvm \
    -m 512 \
    -smp 2 \
    -bios "$OVMF_CODE" \
    -drive file="$QCOW2_IMAGE",if=virtio,format=qcow2 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=net0 \
    -nographic \
    -serial mon:stdio
