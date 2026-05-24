#!/bin/bash
# 05-pack-image.sh - 打包镜像（三个版本）
# 1. alipne.raw                  - RAW 格式（btrfs zstd:3 压缩，用于阿里云）
# 2. alipne.qcow2                - QCOW2 格式（btrfs zstd:3 压缩，用于本地测试）
# 3. alipne-nocompress.qcow2     - QCOW2 格式（btrfs 无压缩，体积大但读写快）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/output"

RAW_IMAGE="$OUTPUT_DIR/alipne.raw"
RAW_NOCOMPRESS="$OUTPUT_DIR/alipne-nocompress.raw"
QCOW2_IMAGE="$OUTPUT_DIR/alipne.qcow2"
QCOW2_NOCOMPRESS="$OUTPUT_DIR/alipne-nocompress.qcow2"

MOUNT_BASE="/tmp/alipne-decompress-$$"

echo "==> 镜像打包（三个版本）"
echo ""

# 检查源 raw 镜像
if [ ! -f "$RAW_IMAGE" ]; then
    echo "错误: RAW 镜像不存在: $RAW_IMAGE"
    exit 1
fi

echo "源 RAW 镜像:"
ls -lh "$RAW_IMAGE"
echo ""

# ==========================================
# 版本 1: alipne.qcow2 (带 btrfs 压缩)
# ==========================================
echo "==> [1/3] 生成 alipne.qcow2（带 btrfs zstd:3 压缩）..."
rm -f "$QCOW2_IMAGE"
qemu-img convert -f raw -O qcow2 -c \
    "$RAW_IMAGE" "$QCOW2_IMAGE"
echo "  ✓ 已生成: $(ls -lh "$QCOW2_IMAGE" | awk '{print $5}')"
echo ""

# ==========================================
# 版本 2: alipne-nocompress.qcow2 (无 btrfs 压缩)
# ==========================================
echo "==> [2/3] 生成 alipne-nocompress.qcow2（无 btrfs 压缩）..."

# 复制原 raw 镜像
echo "  复制 raw 镜像..."
cp "$RAW_IMAGE" "$RAW_NOCOMPRESS"

# 挂载镜像
echo "  挂载镜像..."
LOOP_DEV=$(losetup -f --show -P "$RAW_NOCOMPRESS")
echo "  Loop 设备: $LOOP_DEV"

sleep 2
if [ ! -e "${LOOP_DEV}p2" ]; then
    kpartx -a "$LOOP_DEV"
    sleep 1
fi

# 解压缩函数：挂载子卷并重写所有文件
decompress_subvol() {
    local subvol="$1"
    local mount_target="$2"

    echo "  -> 处理子卷 $subvol..."
    mkdir -p "$mount_target"

    # 使用 compress=no 挂载
    mount -o "subvol=$subvol,compress=no,noatime" "${LOOP_DEV}p2" "$mount_target"

    # 设置子卷不压缩属性
    btrfs property set "$mount_target" compression none 2>/dev/null || true

    # 遍历所有文件，重写以解压缩
    local total=$(find "$mount_target" -type f -size +0c 2>/dev/null | wc -l)
    echo "     找到 $total 个文件需要重写"

    find "$mount_target" -type f -size +0c -print0 2>/dev/null | while IFS= read -r -d '' f; do
        # 重写文件以应用新的压缩设置（即不压缩）
        if cp --preserve=all "$f" "${f}.tmp" 2>/dev/null; then
            mv -f "${f}.tmp" "$f" 2>/dev/null || rm -f "${f}.tmp"
        fi
    done

    # 同步并卸载
    sync
    umount "$mount_target"
    rmdir "$mount_target"
}

# 处理三个子卷
decompress_subvol "@" "${MOUNT_BASE}-root"
decompress_subvol "@home" "${MOUNT_BASE}-home"
decompress_subvol "@var_log" "${MOUNT_BASE}-varlog"

# 同步并释放 loop 设备
sync
losetup -d "$LOOP_DEV" 2>/dev/null || kpartx -d "$LOOP_DEV" 2>/dev/null || true
echo "  ✓ 解压缩完成"

# 转换为 qcow2
echo "  转换为 qcow2..."
rm -f "$QCOW2_NOCOMPRESS"
qemu-img convert -f raw -O qcow2 -c \
    "$RAW_NOCOMPRESS" "$QCOW2_NOCOMPRESS"
echo "  ✓ 已生成: $(ls -lh "$QCOW2_NOCOMPRESS" | awk '{print $5}')"

# 删除中间 raw 文件
rm -f "$RAW_NOCOMPRESS"
echo ""

# ==========================================
# 版本 3: alipne.raw (已存在)
# ==========================================
echo "==> [3/3] 保留 alipne.raw（用于阿里云）..."
echo "  ✓ 已存在: $(ls -lh "$RAW_IMAGE" | awk '{print $5}')"
echo ""

# ==========================================
# 显示最终结果
# ==========================================
echo "=========================================="
echo "  打包完成 - 三个版本"
echo "=========================================="
echo ""

echo "镜像文件:"
ls -lh "$OUTPUT_DIR"/alipne*.raw "$OUTPUT_DIR"/alipne*.qcow2 2>/dev/null
echo ""

echo "镜像信息:"
echo ""
echo "[1] alipne.raw (用于阿里云导入):"
qemu-img info "$RAW_IMAGE" | head -5
echo ""
echo "[2] alipne.qcow2 (带 btrfs 压缩，体积小):"
qemu-img info "$QCOW2_IMAGE" | head -5
echo ""
echo "[3] alipne-nocompress.qcow2 (无 btrfs 压缩，读写快):"
qemu-img info "$QCOW2_NOCOMPRESS" | head -5
echo ""

echo "使用建议:"
echo "  - 阿里云导入:    使用 alipne.raw（镜像格式选 RAW）"
echo "  - 本地测试:      使用 alipne.qcow2（体积小，加载稍慢）"
echo "  - 性能优先:      使用 alipne-nocompress.qcow2（体积大，读写快）"
echo ""
