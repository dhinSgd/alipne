#!/bin/bash
# 05-pack-image.sh - 打包镜像（三个版本）
# 1. alipne.raw                  - RAW 格式，btrfs + zstd:3 压缩（用于阿里云）
# 2. alipne.qcow2                - QCOW2 格式，btrfs + zstd:3 压缩（用于本地测试）
# 3. alipne-nocompress.qcow2     - QCOW2 格式，ext4 文件系统（性能优先）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/output"

RAW_IMAGE="$OUTPUT_DIR/alipne.raw"
EXT4_RAW="$OUTPUT_DIR/alipne-nocompress.raw"
QCOW2_IMAGE="$OUTPUT_DIR/alipne.qcow2"
QCOW2_NOCOMPRESS="$OUTPUT_DIR/alipne-nocompress.qcow2"

EXT4_SIZE="990M"

BTRFS_MOUNT="/tmp/alipne-btrfs-$$"
EXT4_MOUNT="/tmp/alipne-ext4-$$"

echo "==> 镜像打包（三个版本）"
echo ""

if [ ! -f "$RAW_IMAGE" ]; then
    echo "错误: RAW 镜像不存在: $RAW_IMAGE"
    exit 1
fi

echo "源 RAW 镜像:"
ls -lh "$RAW_IMAGE"
echo ""

# ==========================================
# 版本 1: alipne.qcow2 (btrfs + zstd:3 压缩)
# ==========================================
echo "==> [1/3] 生成 alipne.qcow2（btrfs + zstd:3 压缩）..."
rm -f "$QCOW2_IMAGE"
qemu-img convert -f raw -O qcow2 -c "$RAW_IMAGE" "$QCOW2_IMAGE"
echo "  ✓ 已生成: $(ls -lh "$QCOW2_IMAGE" | awk '{print $5}')"
echo ""

# ==========================================
# 版本 2: alipne-nocompress.qcow2 (ext4 文件系统)
# ==========================================
echo "==> [2/3] 生成 alipne-nocompress.qcow2（ext4 文件系统，无 btrfs）..."

# --- 创建空白 ext4 镜像 ---
echo "  -> 创建空白镜像 ($EXT4_SIZE)..."
rm -f "$EXT4_RAW"
qemu-img create -f raw "$EXT4_RAW" "$EXT4_SIZE"

echo "  -> 创建 GPT 分区表..."
parted -s "$EXT4_RAW" mklabel gpt
parted -s "$EXT4_RAW" mkpart primary fat32 1MiB 65MiB
parted -s "$EXT4_RAW" set 1 esp on
parted -s "$EXT4_RAW" mkpart primary ext4 65MiB 100%

echo "  -> 挂载 loop 设备..."
EXT4_LOOP=$(losetup -f --show -P "$EXT4_RAW")
echo "     Loop: $EXT4_LOOP"
sleep 2
[ ! -e "${EXT4_LOOP}p2" ] && { kpartx -a "$EXT4_LOOP"; sleep 1; }

echo "  -> 格式化分区..."
mkfs.fat -F32 -n EFI "${EXT4_LOOP}p1" >/dev/null
mkfs.ext4 -q -F -L alipne "${EXT4_LOOP}p2"

# --- 挂载源 btrfs 镜像（只读）---
echo "  -> 挂载源 btrfs 镜像..."
BTRFS_LOOP=$(losetup -f --show -P "$RAW_IMAGE")
echo "     Loop: $BTRFS_LOOP"
sleep 2
[ ! -e "${BTRFS_LOOP}p2" ] && { kpartx -a "$BTRFS_LOOP"; sleep 1; }

mkdir -p "$BTRFS_MOUNT"
mount -o "subvol=@,ro" "${BTRFS_LOOP}p2" "$BTRFS_MOUNT"
mkdir -p "$BTRFS_MOUNT/home" "$BTRFS_MOUNT/var/log" "$BTRFS_MOUNT/boot/efi"
mount -o "subvol=@home,ro" "${BTRFS_LOOP}p2" "$BTRFS_MOUNT/home" 2>/dev/null || true
mount -o "subvol=@var_log,ro" "${BTRFS_LOOP}p2" "$BTRFS_MOUNT/var/log" 2>/dev/null || true
mount -o ro "${BTRFS_LOOP}p1" "$BTRFS_MOUNT/boot/efi"

# --- 挂载目标 ext4 镜像 ---
echo "  -> 挂载目标 ext4 镜像..."
mkdir -p "$EXT4_MOUNT"
mount "${EXT4_LOOP}p2" "$EXT4_MOUNT"
mkdir -p "$EXT4_MOUNT/boot/efi"
mount "${EXT4_LOOP}p1" "$EXT4_MOUNT/boot/efi"

# --- rsync 文件 ---
echo "  -> rsync 文件到 ext4..."
rsync -aHAX --numeric-ids --info=stats1 \
    --exclude='/proc/*' --exclude='/sys/*' --exclude='/dev/*' \
    --exclude='/tmp/*' --exclude='/run/*' --exclude='/mnt/*' \
    --exclude='/.snapshots' \
    "$BTRFS_MOUNT/" "$EXT4_MOUNT/"

echo "  -> rsync EFI 分区..."
rsync -aHAX --numeric-ids "$BTRFS_MOUNT/boot/efi/" "$EXT4_MOUNT/boot/efi/"

# --- 获取新 UUID ---
EXT4_ROOT_UUID=$(blkid -s UUID -o value "${EXT4_LOOP}p2")
EXT4_EFI_UUID=$(blkid -s UUID -o value "${EXT4_LOOP}p1")
echo "  -> 新 Root UUID: $EXT4_ROOT_UUID"
echo "  -> 新 EFI UUID:  $EXT4_EFI_UUID"

# --- 重写 fstab（ext4，无子卷） ---
echo "  -> 重写 fstab..."
cat > "$EXT4_MOUNT/etc/fstab" <<FSTAB
# /etc/fstab - 文件系统挂载表（ext4 版本）

UUID=$EXT4_ROOT_UUID  /          ext4   defaults,noatime,errors=remount-ro  0  1
UUID=$EXT4_EFI_UUID   /boot/efi  vfat   defaults,noatime                    0  2

tmpfs                 /tmp       tmpfs  defaults,size=128M,mode=1777        0  0
tmpfs                 /run       tmpfs  defaults,size=64M                   0  0
FSTAB

# --- 重写 mkinitfs.conf（不需要 btrfs） ---
echo "  -> 重写 mkinitfs.conf..."
mkdir -p "$EXT4_MOUNT/etc/mkinitfs"
cat > "$EXT4_MOUNT/etc/mkinitfs/mkinitfs.conf" <<'MKINITFS'
features="ata base ide scsi usb virtio nvme ext4"
MKINITFS

# --- chroot 重新生成 initramfs 和重装 grub ---
echo "  -> chroot 重装 grub 和 initramfs..."
mount -t proc proc "$EXT4_MOUNT/proc"
mount -t sysfs sys "$EXT4_MOUNT/sys"
mount --bind /dev "$EXT4_MOUNT/dev"

chroot "$EXT4_MOUNT" /bin/sh <<'CHROOT_EOF'
set -e

# 重新生成 initramfs（不含 btrfs）
for k in /lib/modules/*; do
    KVER=$(basename "$k")
    echo "     mkinitfs: $KVER"
    mkinitfs "$KVER"
done

# 重新安装 grub（指向新 UUID）
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
    --bootloader-id=alipne --recheck --no-floppy \
    --no-nvram --removable >/dev/null

# 重新生成 grub 配置（自动读取新 UUID）
grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tail -3
CHROOT_EOF

# --- 清理 ---
echo "  -> 清理挂载点..."
umount "$EXT4_MOUNT/dev"
umount "$EXT4_MOUNT/sys"
umount "$EXT4_MOUNT/proc"
umount "$EXT4_MOUNT/boot/efi"
umount "$EXT4_MOUNT"

umount "$BTRFS_MOUNT/boot/efi" 2>/dev/null || true
umount "$BTRFS_MOUNT/var/log" 2>/dev/null || true
umount "$BTRFS_MOUNT/home" 2>/dev/null || true
umount "$BTRFS_MOUNT"

losetup -d "$EXT4_LOOP" 2>/dev/null || kpartx -d "$EXT4_LOOP" 2>/dev/null || true
losetup -d "$BTRFS_LOOP" 2>/dev/null || kpartx -d "$BTRFS_LOOP" 2>/dev/null || true

rmdir "$BTRFS_MOUNT" "$EXT4_MOUNT" 2>/dev/null || true

# --- 转换为 qcow2 ---
echo "  -> 转换为 qcow2..."
rm -f "$QCOW2_NOCOMPRESS"
qemu-img convert -f raw -O qcow2 -c "$EXT4_RAW" "$QCOW2_NOCOMPRESS"
echo "  ✓ 已生成: $(ls -lh "$QCOW2_NOCOMPRESS" | awk '{print $5}')"

# 删除中间 raw
rm -f "$EXT4_RAW"
echo ""

# ==========================================
# 版本 3: alipne.raw (已存在)
# ==========================================
echo "==> [3/3] 保留 alipne.raw（btrfs，用于阿里云）..."
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
echo "[1] alipne.raw (btrfs + zstd:3，用于阿里云导入):"
qemu-img info "$RAW_IMAGE" | head -5
echo ""
echo "[2] alipne.qcow2 (btrfs + zstd:3，体积小):"
qemu-img info "$QCOW2_IMAGE" | head -5
echo ""
echo "[3] alipne-nocompress.qcow2 (ext4 文件系统，读写快):"
qemu-img info "$QCOW2_NOCOMPRESS" | head -5
echo ""

echo "使用建议:"
echo "  - 阿里云导入:    使用 alipne.raw（镜像格式选 RAW）"
echo "  - 本地测试:      使用 alipne.qcow2（btrfs 压缩，体积小）"
echo "  - 性能优先:      使用 alipne-nocompress.qcow2（ext4 文件系统）"
echo ""
