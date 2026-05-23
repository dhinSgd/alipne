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
mount -o subvol=@,compress=zstd:9,noatime "${LOOP_DEV}p2" "$MOUNT_POINT"

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

echo "==> btrfs 碎片整理和重新压缩..."
btrfs filesystem defragment -r -czstd "$MOUNT_POINT"

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
