#!/bin/bash
# 05-pack-image.sh - 打包镜像

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/output"

RAW_IMAGE="$OUTPUT_DIR/alipne.raw"
QCOW2_IMAGE="$OUTPUT_DIR/alipne.qcow2"

echo "==> 镜像打包"
echo ""

# RAW 镜像已经在 02-build-rootfs.sh 中创建
if [ ! -f "$RAW_IMAGE" ]; then
    echo "错误: RAW 镜像不存在: $RAW_IMAGE"
    exit 1
fi

echo "RAW 镜像信息:"
ls -lh "$RAW_IMAGE"
echo ""

# 可选：创建 QCOW2 格式（用于本地测试）
echo "==> 创建 QCOW2 格式（用于本地 QEMU 测试）..."
rm -f "$QCOW2_IMAGE"

# 转换为 QCOW2（使用标准 zlib 压缩）
qemu-img convert -f raw -O qcow2 -c \
    "$RAW_IMAGE" "$QCOW2_IMAGE"

echo ""
echo "==> 镜像信息..."
echo ""
echo "RAW 镜像（用于阿里云导入）:"
ls -lh "$RAW_IMAGE"
echo ""
echo "QCOW2 镜像（用于本地测试）:"
ls -lh "$QCOW2_IMAGE"
qemu-img info "$QCOW2_IMAGE"

echo ""
echo "✓ 镜像打包完成"
echo ""
echo "部署到阿里云："
echo "  1. 上传 RAW 镜像到 OSS:"
echo "     ossutil cp $RAW_IMAGE oss://your-bucket/alipne.raw"
echo ""
echo "  2. 在阿里云控制台导入镜像:"
echo "     - 镜像格式: RAW"
echo "     - OSS 对象: alipne.raw"
echo ""
echo "本地测试："
echo "  make test  # 使用 QCOW2 镜像"
echo ""
