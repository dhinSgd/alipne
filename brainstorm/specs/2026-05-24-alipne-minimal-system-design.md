# alipne 极简 Alpine Linux 系统设计

**日期**：2026-05-24
**作者**：sunxizhen + Claude
**状态**：已批准

## 1. 目标与背景

构建一个基于 Alpine Linux 的极小化系统镜像，用于部署到阿里云低配置 ECS 实例。

### 目标平台

- **CPU**：2 核（SysBench 单核 1062 分，双核 1777 分）
- **内存**：0.5 GB
- **硬盘**：1 GB
- **CPU 性能**：中等
- **硬盘 I/O**：较慢（4K 随机 5.57 MB/s，顺序 113 MB/s）

### 核心需求

1. 极小化系统占用，留出尽可能多的空间给应用
2. 使用 zram 以 CPU 换取更多可用内存（目标总可用内存 ~1 GB）
3. 使用 btrfs zstd 压缩硬盘（zstd:9，约 2.2-2.5x 压缩比）
4. 用途：轻量级服务器（SSH 为主，未来可能加反向代理）
5. 启动方式：UEFI/GPT
6. 在当前 Ubuntu 系统中构建、测试、打包

## 2. 系统架构

```text
┌─────────────────────────────────────────────────┐
│  阿里云 ECS 虚拟机 (2c / 0.5G RAM / 1G Disk)    │
│                                                  │
│  Alpine Linux (Virtual edition)                  │
│  - Kernel: linux-virt                            │
│  - Init: OpenRC                                  │
│  - libc: musl                                    │
│                                                  │
│  内存层：                                        │
│    物理 RAM 0.5G + zram swap 500MB              │
│    总可用 ≈ 0.5G + 0.5G - 0.2G = ~0.8-1G        │
│                                                  │
│  存储层：                                        │
│    /dev/vda (1G, GPT)                            │
│    ├ vda1: 100MB FAT32 (EFI)                    │
│    └ vda2: ~900MB btrfs (zstd:9, noatime)       │
│                                                  │
│  服务层：                                        │
│    sshd, chronyd, cloud-init, qemu-guest-agent  │
└─────────────────────────────────────────────────┘
```

## 3. 分区和文件系统设计

### 分区方案

```text
/dev/vda (1G, GPT)
├── vda1: EFI System Partition
│         大小: 64MB
│         文件系统: FAT32
│         挂载: /boot/efi
│
└── vda2: Root Partition
          大小: ~936MB
          文件系统: btrfs
          挂载: /
          挂载选项:
            - compress=zstd:9
            - noatime
            - ssd
            - space_cache=v2
            - discard=async

          btrfs 子卷布局:
            @          → /        (根文件系统)
            @home      → /home    (用户数据)
            @var_log   → /var/log (日志)
            @snapshots → /.snapshots (快照存储)
```

### 关键决策

- **不创建 swap 分区**：完全使用 zram swap
- **不独立 /boot 分区**：内核放在 btrfs 根，省一个分区
- **EFI 分区 64MB**：足够 grub 和内核使用
- **`noatime`**：避免每次读取都触发写入（小硬盘的大敌）
- **`discard=async`**：异步 TRIM 通知

## 4. 内存管理（zram）

### zram 配置

- **设备大小**：500MB（物理 RAM 的 100%）
- **压缩算法**：zstd（与 btrfs 一致）
- **预估压缩比**：~2.5x
- **最坏情况物理 RAM 占用**：~200MB
- **swappiness**：100（优先使用 zram，比硬盘 swap 快 100 倍）

### `/etc/conf.d/zram-init`

```bash
num_devices=1

load0="swap"
type0="swap"
flag0="zram"
size0=500
maxs0=2
algo0="zstd"
labl0="zram-swap"
uuid0=""
notr0=""
mntp0=""
opts0=""
opte0=""
```text

### `/etc/sysctl.d/99-zram.conf`

```bash
vm.swappiness=100
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=1
vm.dirty_ratio=5
vm.page-cluster=0
```

## 5. 软件包列表

### 必需的核心包

```text
# 基础系统
alpine-base
alpine-conf
linux-virt
linux-firmware-none

# 启动相关
grub
grub-efi
efibootmgr

# 文件系统
btrfs-progs
e2fsprogs
dosfstools

# 内存管理
zram-init

# 网络与服务
chrony
openssh-server

# 基础工具
nano
curl
wget
dcron

# 云平台支持
cloud-init
qemu-guest-agent
```

### 明确不安装

- 文档类：docs, man-pages, info-pages
- 开发工具：gcc, make, build-base
- 桌面/图形：xorg-server, mesa, fontconfig
- 数据库/解释器：sqlite, python, perl, ruby
- 网络服务：nginx, apache, postfix, samba
- 调试工具：strace, ltrace, gdb, tcpdump
- iproute2（用 busybox 自带的 ip 即可）

### 精简清理

```bash
rm -rf /usr/share/man/*
rm -rf /usr/share/doc/*
rm -rf /usr/share/info/*
rm -rf /usr/share/i18n/locales/*
rm -rf /usr/share/locale/*
rm -rf /var/cache/apk/*
```

**内核模块清理（黑名单模式）**：
删除服务器绝对用不到的模块，采用保守策略：
- 显卡驱动（drivers/gpu/, drivers/video/fbdev/）
- 声卡驱动（sound/）
- 蓝牙（drivers/bluetooth/, net/bluetooth/）
- 无线网卡（drivers/net/wireless/）
- 物理网卡（drivers/net/ethernet/，虚拟化用 virtio-net）
- 输入设备（键盘/鼠标/触摸板）
- 多媒体设备（摄像头/电视卡）
- 其他：InfiniBand, PCMCIA, 游戏手柄, LED 控制等

预估节省：20-40MB

## 6. 关键配置文件

### 6.1 `/etc/fstab`

```text
UUID=<root-uuid>  /          btrfs  subvol=@,compress=zstd:9,noatime,ssd,space_cache=v2,discard=async  0  0
UUID=<root-uuid>  /home      btrfs  subvol=@home,compress=zstd:9,noatime,ssd,space_cache=v2            0  0
UUID=<root-uuid>  /var/log   btrfs  subvol=@var_log,compress=zstd:9,noatime,ssd,space_cache=v2         0  0
UUID=<efi-uuid>   /boot/efi  vfat   defaults,noatime                                                    0  2

tmpfs             /tmp       tmpfs  defaults,size=128M,mode=1777                                        0  0
tmpfs             /run       tmpfs  defaults,size=64M                                                   0  0
```

**注意**：不配置任何 swap，由 zram-init 服务管理。

### 6.2 `/etc/ssh/sshd_config`

```text
Port 22
ListenAddress 0.0.0.0

PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no

X11Forwarding no
AllowAgentForwarding no
UseDNS no
```

### 6.3 DNS 配置（智能回退）

`/etc/resolv.conf`：

```text
# DNS 配置 - 由 DHCP 自动获取
# 如果 DHCP 未提供 DNS，将自动回退到 Cloudflare + Google DNS
# 此文件由 udhcpc 管理
```

`/etc/network/interfaces`：

```text
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
```

`/etc/udhcpc/post-bound/dns-fallback`（智能回退脚本）：

```bash
#!/bin/sh
# DNS 回退脚本：如果 DHCP 未提供 DNS，使用 Cloudflare + Google

RESOLV_CONF="/etc/resolv.conf"
FALLBACK_DNS="1.1.1.1 8.8.8.8 1.0.0.1 8.8.4.4"

# 检查 resolv.conf 是否有有效的 nameserver
if ! grep -q "^nameserver" "$RESOLV_CONF" 2>/dev/null; then
    echo "# DHCP 未提供 DNS，使用回退 DNS 服务器" > "$RESOLV_CONF"
    for dns in $FALLBACK_DNS; do
        echo "nameserver $dns" >> "$RESOLV_CONF"
    done
    echo "options edns0 single-request-reopen" >> "$RESOLV_CONF"
    logger -t udhcpc "DHCP 未提供 DNS，已配置回退 DNS: $FALLBACK_DNS"
fi
```

**工作原理**：
- DHCP 成功提供 DNS → 使用 DHCP 的 DNS
- DHCP 未提供 DNS → 自动回退到 Cloudflare + Google DNS

### 6.4 cloud-init 最小配置

```yaml
# /etc/cloud/cloud.cfg
datasource_list: [ AliYun, NoCloud, None ]

system_info:
  default_user:
    name: alipne
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [ wheel ]
    shell: /bin/ash
  distro: alpine

cloud_init_modules:
  - migrator
  - bootcmd
  - write-files
  - set_hostname
  - update_hostname
  - users-groups
  - ssh

cloud_config_modules:
  - runcmd

cloud_final_modules:
  - scripts-user
  - final-message
```text

### 6.5 OpenRC 启动服务

```bash
# sysinit
devfs, dmesg, mdev, hwdrivers, modules

# boot
hwclock, modules, sysctl, hostname, bootmisc, syslog
zram-init

# default
networking, sshd, chronyd, crond
qemu-guest-agent, cloud-init
```

明确禁用：acpid, klogd, mdadm

**注意**：dcron 服务名为 `crond`，需要在 default runlevel 启动。

## 7. 项目目录结构

```text
/workspace/alipne/
├── build.sh                     # 主构建脚本
├── Makefile                     # 简化常用命令
├── config/
│   ├── packages.list            # 要安装的包列表
│   ├── world                    # alpine world 文件
│   └── kernel-modules-blacklist.txt  # 内核模块黑名单
├── overlay/                     # 覆盖到根文件系统的文件
│   ├── etc/
│   │   ├── fstab
│   │   ├── conf.d/zram-init
│   │   ├── ssh/sshd_config
│   │   ├── sysctl.d/99-zram.conf
│   │   ├── resolv.conf
│   │   ├── network/interfaces
│   │   ├── udhcpc/post-bound/dns-fallback
│   │   └── cloud/cloud.cfg
│   └── etc/local.d/
│       └── post-install.start
├── scripts/
│   ├── 01-prepare-host.sh       # 安装宿主机构建依赖
│   ├── 02-build-rootfs.sh       # 构建 rootfs
│   ├── 03-setup-bootloader.sh   # 配置 grub/UEFI
│   ├── 04-cleanup.sh            # 精简清理
│   ├── 05-pack-image.sh         # 打包成 qcow2
│   └── 06-test-image.sh         # QEMU 启动测试
├── output/
│   ├── alipne.raw               # 原始镜像（中间产物）
│   └── alipne.qcow2             # 最终镜像（上传用）
└── README.md
```

## 8. 构建流程

```text
1. 准备宿主机环境 (Ubuntu)
   apt install qemu-utils qemu-system-x86
   apt install btrfs-progs dosfstools parted
   apt install grub-efi-amd64-bin
   下载 alpine-make-vm-image

2. 创建空白镜像文件 (1GB raw)
   qemu-img create -f raw alipne.raw 1G
   parted: 创建 GPT 分区表
     vda1: 64MB FAT32 (EFI)
     vda2: 936MB btrfs

3. 挂载并安装 Alpine
   mkfs.fat -F32 /dev/loop0p1
   mkfs.btrfs /dev/loop0p2
   mount -o compress=zstd:9,noatime ...
   创建 btrfs 子卷 (@, @home, @var_log)
   apk --root /mnt --initdb add ...packages...

4. 应用 overlay 文件
   cp -a overlay/* /mnt/
   配置 fstab、zram、sshd 等

5. 安装并配置 grub (UEFI)
   chroot /mnt grub-install --target=x86_64-efi
   grub-mkconfig -o /boot/grub/grub.cfg

6. 清理精简
   删除文档、locale、apk 缓存
   删除黑名单中的内核模块（显卡/声卡/蓝牙/无线等）
   btrfs filesystem defragment（重新压缩）

7. 卸载并转换格式
   umount /mnt
   losetup -d /dev/loop0
   qemu-img convert -f raw -O qcow2 -c \
       alipne.raw alipne.qcow2

8. 测试启动 (QEMU)
   验证: 启动成功、SSH 可登录、zram 工作正常
```

### 构建命令

```bash
make all           # 一键构建
make prepare       # 准备宿主机
make rootfs        # 构建 rootfs
make bootloader    # 安装 grub
make cleanup       # 精简
make pack          # 打包 qcow2
make test          # QEMU 测试
```text

## 9. 测试方案

### QEMU 启动命令

```bash
qemu-system-x86_64 \
    -enable-kvm \
    -m 512 \
    -smp 2 \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -drive file=output/alipne.qcow2,if=virtio \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=net0 \
    -nographic
```

### 验证检查清单

```text
□ 启动验证
  □ UEFI 启动成功
  □ grub 菜单正常
  □ 内核加载成功
  □ 启动时间 < 30 秒

□ SSH 验证
  □ 密码登录可用
  □ key 登录可用

□ zram 验证
  □ swapon 显示 /dev/zram0 (500MB, zstd)
  □ swappiness = 100

□ btrfs 验证
  □ mount 显示 compress=zstd:9, noatime
  □ 子卷 @, @home, @var_log 存在

□ 系统占用验证
  □ 根分区使用 < 100MB
  □ 可用空间 > 800MB
  □ 系统空闲内存 > 350MB

□ 服务验证
  □ sshd, chronyd, qemu-guest-agent, cloud-init 都已启动

□ 网络验证
  □ ping 1.1.1.1 通
  □ DNS 智能回退工作正常（DHCP 或 Cloudflare + Google）

□ 重启验证
  □ 能正常重启
  □ 服务恢复

□ 压力测试
  □ 内存压力下 zram 工作正常
  □ 写入压力下系统响应正常
```

## 9.1 初始登录方式

构建镜像时设置默认 root 密码（如 `SlimAlpine123`），同时 cloud-init 在阿里云首次启动时会注入控制台设置的 SSH key。两种登录方式：

1. **首次启动后通过控制台/VNC 登录**：使用默认 root 密码
2. **通过 SSH 远程登录**：
   - 使用阿里云控制台注入的 SSH key（推荐）
   - 或使用默认 root 密码（建议首次登录后立即修改）

构建脚本中：

```bash
# 在 chroot 中设置默认 root 密码
echo "root:SlimAlpine123" | chpasswd
```

部署后建议：

```bash
# 首次登录后立即修改密码
passwd

# 上传自己的 SSH key 后禁用密码登录（可选，更安全）
# 编辑 /etc/ssh/sshd_config: PasswordAuthentication no
```

## 10. 阿里云部署流程

```text
1. 阿里云控制台 → ECS → 镜像 → 自定义镜像 → 导入镜像
2. 准备 OSS bucket
3. 上传 output/alipne.qcow2 到 OSS
4. 在控制台填写：
   - 镜像格式: QCOW2
   - 操作系统: Linux - Customized Linux
   - 系统盘大小: 1 GiB
   - 架构: x86_64
   - 启动模式: UEFI
5. 等待导入完成（5-15 分钟）
6. 用该镜像创建 ECS 实例（2c/0.5g/1g）
```

## 11. 内部一致性检查

- ✓ 内存配置：zram 500MB + 物理 0.5G = ~1G 总可用（符合需求）
- ✓ 硬盘配置：EFI 100MB + btrfs 900MB = 1G（符合）
- ✓ 压缩配置：btrfs zstd:9 + zram zstd（一致）
- ✓ SSH 配置：允许 root 密码登录（符合用户要求）
- ✓ DNS 配置：DHCP 优先，回退到 Cloudflare + Google（符合用户要求）
- ✓ 不使用硬盘 swap：仅 zram（符合）
- ✓ 启动方式：UEFI/GPT（符合）
- ✓ 镜像格式：QCOW2（符合）

## 12. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| UEFI 启动失败 | 系统无法启动 | 用 OVMF 在 QEMU 中预先验证；保留 grub 命令行救援 |
| btrfs 压缩异常 | 文件读取失败 | 选择稳定级别 zstd:9；测试阶段强制 `btrfs scrub` 验证 |
| zram-init 不启动 | swap 不可用 | 启动后检查 `swapon`；提供回退脚本 |
| 1G 硬盘溢出 | 写入失败 | 构建后实测占用 < 100MB；监控脚本预警 |
| cloud-init 在阿里云不识别 | 无法注入 SSH key | 默认设置 root 密码；datasource_list 包含 AliYun |
| 内核模块不全 | 设备识别失败 | 使用黑名单模式，只删除明确不需要的硬件驱动 |

## 13. 预估指标

| 指标 | 预估值 |
|------|--------|
| 系统占用（虚拟机内 df） | ~70-90 MB |
| 可用硬盘空间 | ~840 MB |
| 虚拟内存总量 | ~1 GB（0.5G RAM + 0.5G zram） |
| QCOW2 镜像文件大小 | ~100-150 MB |
| 启动时间 | < 30 秒 |
| btrfs 压缩比 | ~2.2-2.5x |
| zram 压缩比 | ~2.5x |
