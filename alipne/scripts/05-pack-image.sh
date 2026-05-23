#!/bin/bash
# 05-pack-image.sh - 打包成 qcow2 格式

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/output"

RAW_IMAGE="$OUTPUT_DIR/alipne.raw"
QCOW2_IMAGE="$OUTPUT_DIR/alipne.qcow2"

echo "==> 转换镜像格式 (raw -> qcow2)..."

# 删除旧的 qcow2 镜像
rm -f "$QCOW2_IMAGE"

# 转换并压缩（使用标准 zlib 压缩，兼容阿里云）
# 注意：不使用 compression_type=zstd，阿里云不支持
qemu-img convert -f raw -O qcow2 -c \
    "$RAW_IMAGE" "$QCOW2_IMAGE"

echo "==> 镜像信息..."
qemu-img info "$QCOW2_IMAGE"

echo ""
echo "==> 文件大小对比..."
echo "Raw 镜像:   $(du -h "$RAW_IMAGE" | cut -f1)"
echo "QCOW2 镜像: $(du -h "$QCOW2_IMAGE" | cut -f1)"

echo ""
echo "✓ 镜像打包完成"
echo "  输出文件: $QCOW2_IMAGE"
echo ""
echo "可以使用以下命令测试:"
echo "  make test"
echo "或上传到阿里云 OSS 进行部署"
echo ""
