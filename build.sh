#!/bin/bash
# build.sh - alipne 极简 Alpine Linux 系统镜像构建主脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  alipne - 极简 Alpine Linux 系统构建"
echo "=========================================="
echo ""

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "错误: 需要 root 权限运行构建脚本"
    echo "请使用: sudo ./build.sh"
    exit 1
fi

# 执行构建步骤
echo "步骤 1/6: 准备宿主机环境"
bash "$SCRIPT_DIR/scripts/01-prepare-host.sh"

echo ""
echo "步骤 2/6: 构建根文件系统"
bash "$SCRIPT_DIR/scripts/02-build-rootfs.sh"

echo ""
echo "步骤 3/6: 安装引导加载器"
bash "$SCRIPT_DIR/scripts/03-setup-bootloader.sh"

echo ""
echo "步骤 4/6: 精简清理"
bash "$SCRIPT_DIR/scripts/04-cleanup.sh"

echo ""
echo "步骤 5/6: 打包 qcow2 镜像"
bash "$SCRIPT_DIR/scripts/05-pack-image.sh"

echo ""
echo "=========================================="
echo "  ✓ 构建完成！"
echo "=========================================="
echo ""
echo "镜像文件: $SCRIPT_DIR/output/alipne.qcow2"
echo ""
echo "下一步:"
echo "  1. 测试镜像: make test"
echo "  2. 上传到阿里云 OSS"
echo "  3. 在控制台导入自定义镜像"
echo ""
