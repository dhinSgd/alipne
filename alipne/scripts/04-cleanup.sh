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

echo "==> 精简内核模块..."
# 保留 virtio 相关模块，删除其他不需要的
KERNEL_VERSION=$(ls "$MOUNT_POINT/lib/modules/" | head -1)
MODULES_DIR="$MOUNT_POINT/lib/modules/$KERNEL_VERSION"

if [ -d "$MODULES_DIR" ]; then
    echo "内核版本: $KERNEL_VERSION"

    # 创建临时目录保存需要的模块
    TEMP_MODULES="/tmp/keep-modules-$$"
    mkdir -p "$TEMP_MODULES"

    # 保留 virtio 和必需的模块
    cd "$MODULES_DIR"
    find . -path "*/drivers/virtio/*" -o \
           -path "*/drivers/block/virtio_blk.ko*" -o \
           -path "*/drivers/net/virtio_net.ko*" -o \
           -path "*/drivers/char/hw_random/virtio-rng.ko*" -o \
           -path "*/net/*" -o \
           -path "*/fs/btrfs/*" -o \
           -path "*/fs/fat/*" -o \
           -path "*/fs/vfat/*" -o \
           -path "*/fs/nls/*" -o \
           -path "*/crypto/*" | \
    while read module; do
        mkdir -p "$TEMP_MODULES/$(dirname "$module")"
        cp -a "$module" "$TEMP_MODULES/$module"
    done

    # 删除所有模块
    rm -rf "$MODULES_DIR/kernel"

    # 恢复需要的模块
    mkdir -p "$MODULES_DIR/kernel"
    cp -a "$TEMP_MODULES"/* "$MODULES_DIR/"

    # 重新生成模块依赖
    depmod -b "$MOUNT_POINT" "$KERNEL_VERSION"

    rm -rf "$TEMP_MODULES"

    echo "✓ 内核模块精简完成"
fi

echo "==> btrfs 碎片整理和重新压缩..."
btrfs filesystem defragment -r -czstd "$MOUNT_POINT"

echo "==> 显示磁盘使用情况..."
df -h "$MOUNT_POINT"
du -sh "$MOUNT_POINT"

echo "==> 清理..."
umount "$MOUNT_POINT"
losetup -d "$LOOP_DEV" || kpartx -d "$LOOP_DEV"
rmdir "$MOUNT_POINT"

echo ""
echo "✓ 系统精简完成"
echo ""
