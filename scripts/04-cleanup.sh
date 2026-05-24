#!/bin/bash
# 04-cleanup.sh - 精简清理系统

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/output"
CONFIG_DIR="$PROJECT_DIR/config"

IMAGE_FILE="$OUTPUT_DIR/alipne.raw"
MOUNT_POINT="/tmp/alipne-cleanup-$$"

echo "==> 挂载镜像..."
LOOP_DEV=$(losetup -f --show -P "$IMAGE_FILE")
echo "Loop 设备: $LOOP_DEV"

sleep 2
if [ ! -e "${LOOP_DEV}p1" ]; then
    kpartx -a "$LOOP_DEV"
    sleep 1
fi

mkdir -p "$MOUNT_POINT"
mount -o subvol=@,compress=zstd:3,noatime "${LOOP_DEV}p2" "$MOUNT_POINT"

echo "==> 删除文档和本地化文件..."
rm -rf "$MOUNT_POINT/usr/share/man"/*
rm -rf "$MOUNT_POINT/usr/share/doc"/*
rm -rf "$MOUNT_POINT/usr/share/info"/*
rm -rf "$MOUNT_POINT/usr/share/locale"/*
rm -rf "$MOUNT_POINT/usr/share/i18n/locales"/*

echo "==> 清理 apk 缓存..."
rm -rf "$MOUNT_POINT/var/cache/apk"/*
rm -rf "$MOUNT_POINT/etc/apk/cache"/*

echo "==> 清理临时文件..."
rm -rf "$MOUNT_POINT/tmp"/*
rm -rf "$MOUNT_POINT/var/tmp"/*
rm -rf "$MOUNT_POINT/var/log"/*

echo "==> 清理内核模块（黑名单模式）..."
KERNEL_VERSION=$(ls "$MOUNT_POINT/lib/modules/" | head -1)
MODULES_DIR="$MOUNT_POINT/lib/modules/$KERNEL_VERSION"

if [ -d "$MODULES_DIR" ]; then
    echo "内核版本: $KERNEL_VERSION"

    # 读取黑名单并删除对应模块
    BLACKLIST_FILE="$CONFIG_DIR/kernel-modules-blacklist.txt"
    if [ -f "$BLACKLIST_FILE" ]; then
        DELETED_COUNT=0
        while IFS= read -r pattern; do
            # 跳过注释和空行
            [[ "$pattern" =~ ^#.*$ ]] && continue
            [[ -z "$pattern" ]] && continue

            # 使用 find 查找并删除匹配的模块（支持目录和文件）
            if find "$MODULES_DIR/kernel" -path "*/$pattern" -print -delete 2>/dev/null | grep -q .; then
                echo "  删除: $pattern"
                DELETED_COUNT=$((DELETED_COUNT + 1))
            fi
        done < "$BLACKLIST_FILE"

        # 重新生成模块依赖
        if [ $DELETED_COUNT -gt 0 ]; then
            echo "  已删除 $DELETED_COUNT 项，重新生成依赖..."
            if ! depmod -b "$MOUNT_POINT" "$KERNEL_VERSION" 2>&1; then
                echo "⚠ depmod 警告（可忽略）"
            fi
            echo "✓ 内核模块清理完成"
        else
            echo "✓ 未找到需要删除的模块"
        fi
    else
        echo "⚠ 黑名单文件不存在，跳过内核模块清理"
    fi
fi

echo "==> btrfs 碎片整理和重新压缩..."
if ! btrfs filesystem defragment -r -czstd "$MOUNT_POINT" 2>&1; then
    echo "⚠ btrfs 碎片整理警告（可忽略）"
fi

echo "==> btrfs 空间回收..."
if ! btrfs balance start -dusage=50 "$MOUNT_POINT" 2>&1; then
    echo "⚠ btrfs balance 警告（可忽略）"
fi

echo "==> 显示磁盘使用情况..."
df -h "$MOUNT_POINT"
du -sh "$MOUNT_POINT"

echo "==> 清理..."
sync
umount "$MOUNT_POINT" || umount -l "$MOUNT_POINT"
losetup -d "$LOOP_DEV" || kpartx -d "$LOOP_DEV"
rmdir "$MOUNT_POINT"

echo ""
echo "✓ 系统精简完成"
echo ""
