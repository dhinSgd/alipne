#!/bin/bash
# 03-setup-bootloader.sh - 安装并配置 grub 引导

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/output"

IMAGE_FILE="$OUTPUT_DIR/alipne.raw"
MOUNT_POINT="/tmp/alipne-boot-$$"

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
mount "${LOOP_DEV}p1" "$MOUNT_POINT/boot/efi"

# 挂载虚拟文件系统
mount -t proc proc "$MOUNT_POINT/proc"
mount -t sysfs sys "$MOUNT_POINT/sys"
mount --bind /dev "$MOUNT_POINT/dev"

echo "==> 安装 grub..."

# 在 chroot 中安装 grub
chroot "$MOUNT_POINT" /bin/sh <<'CHROOT_EOF'
set -e

# 安装 grub 到 EFI 分区
# --no-nvram: 跳过 NVRAM 注册（构建环境无 EFI 变量）
# --removable: 安装为默认 /EFI/BOOT/BOOTX64.EFI（云平台/任意 UEFI 固件可启动）
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
    --bootloader-id=alipne --recheck --no-floppy \
    --no-nvram --removable

# 生成 grub 配置
grub-mkconfig -o /boot/grub/grub.cfg

echo "✓ grub 安装完成"
CHROOT_EOF

echo "==> 清理..."
umount "$MOUNT_POINT/dev"
umount "$MOUNT_POINT/sys"
umount "$MOUNT_POINT/proc"
umount "$MOUNT_POINT/boot/efi"
umount "$MOUNT_POINT"

losetup -d "$LOOP_DEV" || kpartx -d "$LOOP_DEV"
rmdir "$MOUNT_POINT"

echo ""
echo "✓ 引导加载器安装完成"
echo ""
