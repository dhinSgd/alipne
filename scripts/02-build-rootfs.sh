#!/bin/bash
# 02-build-rootfs.sh - 构建 Alpine Linux 根文件系统

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/output"
OVERLAY_DIR="$PROJECT_DIR/overlay"
CONFIG_DIR="$PROJECT_DIR/config"

IMAGE_FILE="$OUTPUT_DIR/alipne.raw"
IMAGE_SIZE="1G"
MOUNT_POINT="/tmp/alipne-build-$$"

echo "==> 创建空白镜像文件 ($IMAGE_SIZE)..."
rm -f "$IMAGE_FILE"
qemu-img create -f raw "$IMAGE_FILE" "$IMAGE_SIZE"

echo "==> 创建 GPT 分区表..."
parted -s "$IMAGE_FILE" mklabel gpt
parted -s "$IMAGE_FILE" mkpart primary fat32 1MiB 101MiB
parted -s "$IMAGE_FILE" set 1 esp on
parted -s "$IMAGE_FILE" mkpart primary btrfs 101MiB 100%

echo "==> 设置 loop 设备..."
LOOP_DEV=$(losetup -f --show -P "$IMAGE_FILE")
echo "Loop 设备: $LOOP_DEV"

# 等待分区设备出现
sleep 2
if [ ! -e "${LOOP_DEV}p1" ]; then
    # 尝试使用 kpartx
    kpartx -a "$LOOP_DEV"
    sleep 1
fi

echo "==> 格式化分区..."
# EFI 分区
mkfs.fat -F32 -n EFI "${LOOP_DEV}p1"

# btrfs 根分区
mkfs.btrfs -f -L alipne "${LOOP_DEV}p2"

echo "==> 挂载并创建 btrfs 子卷..."
mkdir -p "$MOUNT_POINT"
mount -o compress=zstd:9,noatime "${LOOP_DEV}p2" "$MOUNT_POINT"

# 创建子卷
btrfs subvolume create "$MOUNT_POINT/@"
btrfs subvolume create "$MOUNT_POINT/@home"
btrfs subvolume create "$MOUNT_POINT/@var_log"
btrfs subvolume create "$MOUNT_POINT/@snapshots"

# 卸载并重新挂载根子卷
umount "$MOUNT_POINT"
mount -o subvol=@,compress=zstd:9,noatime,ssd,space_cache=v2,discard=async \
    "${LOOP_DEV}p2" "$MOUNT_POINT"

# 创建挂载点
mkdir -p "$MOUNT_POINT"/{home,var/log,.snapshots,boot/efi,dev,proc,sys,run,tmp}

# 挂载其他子卷
mount -o subvol=@home,compress=zstd:9,noatime,ssd,space_cache=v2 \
    "${LOOP_DEV}p2" "$MOUNT_POINT/home"
mount -o subvol=@var_log,compress=zstd:9,noatime,ssd,space_cache=v2 \
    "${LOOP_DEV}p2" "$MOUNT_POINT/var/log"

# 挂载 EFI 分区
mount "${LOOP_DEV}p1" "$MOUNT_POINT/boot/efi"

echo "==> 安装 Alpine Linux 基础系统..."

# 获取最新的 Alpine 镜像 URL
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"
ALPINE_VERSION="v3.20"
ALPINE_ARCH="x86_64"

# 从 APKINDEX 动态获取最新的 apk-tools-static 版本号
echo "==> 获取最新的 apk-tools-static 版本..."
rm -rf /tmp/apkindex
mkdir -p /tmp/apkindex
wget -q -O /tmp/apkindex/APKINDEX.tar.gz \
    "$ALPINE_MIRROR/$ALPINE_VERSION/main/$ALPINE_ARCH/APKINDEX.tar.gz"
tar -xzf /tmp/apkindex/APKINDEX.tar.gz -C /tmp/apkindex

# 解析 APKINDEX 找到 apk-tools-static 的版本
APK_TOOLS_VERSION=$(awk '
    /^P:apk-tools-static$/ { found=1; next }
    found && /^V:/ { sub(/^V:/, ""); print; exit }
' /tmp/apkindex/APKINDEX)

if [ -z "$APK_TOOLS_VERSION" ]; then
    echo "错误: 无法从 APKINDEX 获取 apk-tools-static 版本"
    exit 1
fi

APK_TOOLS_FILE="apk-tools-static-${APK_TOOLS_VERSION}.apk"
echo "找到版本: $APK_TOOLS_FILE"

# 下载 apk-tools-static
rm -f /tmp/apk-tools-static.apk
wget -O /tmp/apk-tools-static.apk \
    "$ALPINE_MIRROR/$ALPINE_VERSION/main/$ALPINE_ARCH/$APK_TOOLS_FILE"

# 解压（清理后再解压避免冲突）
rm -rf /tmp/apk-static-extract
mkdir -p /tmp/apk-static-extract
tar -xzf /tmp/apk-tools-static.apk -C /tmp/apk-static-extract
APK_STATIC="/tmp/apk-static-extract/sbin/apk.static"

if [ ! -x "$APK_STATIC" ]; then
    echo "错误: apk.static 未找到或不可执行"
    ls -la /tmp/apk-static-extract/sbin/ 2>&1 || true
    exit 1
fi

# 初始化 apk 数据库
$APK_STATIC --arch $ALPINE_ARCH --root "$MOUNT_POINT" \
    --initdb --allow-untrusted \
    --repository "$ALPINE_MIRROR/$ALPINE_VERSION/main" \
    --repository "$ALPINE_MIRROR/$ALPINE_VERSION/community" \
    add alpine-base alpine-keys

echo "==> 安装软件包..."
# 读取包列表并安装
PACKAGES=$(cat "$CONFIG_DIR/packages.list" | grep -v '^#' | grep -v '^$' | tr '\n' ' ')

$APK_STATIC --arch $ALPINE_ARCH --root "$MOUNT_POINT" \
    --allow-untrusted \
    --repository "$ALPINE_MIRROR/$ALPINE_VERSION/main" \
    --repository "$ALPINE_MIRROR/$ALPINE_VERSION/community" \
    add $PACKAGES

echo "==> 应用 overlay 配置文件..."
cp -av "$OVERLAY_DIR"/* "$MOUNT_POINT/"

echo "==> 获取分区 UUID..."
ROOT_UUID=$(blkid -s UUID -o value "${LOOP_DEV}p2")
EFI_UUID=$(blkid -s UUID -o value "${LOOP_DEV}p1")

echo "Root UUID: $ROOT_UUID"
echo "EFI UUID: $EFI_UUID"

# 替换 fstab 中的 UUID
sed -i "s/ROOT_UUID/$ROOT_UUID/g" "$MOUNT_POINT/etc/fstab"
sed -i "s/EFI_UUID/$EFI_UUID/g" "$MOUNT_POINT/etc/fstab"

echo "==> 配置系统..."

# 挂载必要的虚拟文件系统
mount -t proc proc "$MOUNT_POINT/proc"
mount -t sysfs sys "$MOUNT_POINT/sys"
mount --bind /dev "$MOUNT_POINT/dev"

# 在 chroot 中执行配置
chroot "$MOUNT_POINT" /bin/sh <<'CHROOT_EOF'
set -e

# 设置主机名
echo "SlimAlpine" > /etc/hostname

# 设置 root 密码
echo "root:SlimAlpine123" | chpasswd

# 配置 OpenRC 服务
# sysinit
rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add mdev sysinit
rc-update add hwdrivers sysinit

# boot
rc-update add hwclock boot
rc-update add modules boot
rc-update add sysctl boot
rc-update add hostname boot
rc-update add bootmisc boot
rc-update add syslog boot
rc-update add zram-init boot

# default
rc-update add networking default
rc-update add sshd default
rc-update add chronyd default
rc-update add crond default
rc-update add qemu-guest-agent default
rc-update add cloud-init default
rc-update add cloud-init-local default
rc-update add cloud-config default
rc-update add cloud-final default

# 禁用不需要的服务
rc-update del acpid default 2>/dev/null || true
rc-update del klogd default 2>/dev/null || true

# 配置 SSH
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# 配置时区
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

echo "✓ 系统配置完成"
CHROOT_EOF

echo "==> 清理..."
# 卸载虚拟文件系统
umount "$MOUNT_POINT/dev"
umount "$MOUNT_POINT/sys"
umount "$MOUNT_POINT/proc"

# 卸载所有挂载点
umount "$MOUNT_POINT/boot/efi"
umount "$MOUNT_POINT/var/log"
umount "$MOUNT_POINT/home"
umount "$MOUNT_POINT"

# 释放 loop 设备
losetup -d "$LOOP_DEV" || kpartx -d "$LOOP_DEV"

# 清理临时目录
rmdir "$MOUNT_POINT"

echo ""
echo "✓ 根文件系统构建完成"
echo "  镜像文件: $IMAGE_FILE"
echo ""
