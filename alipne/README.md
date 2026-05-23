# alipne - 极简 Alpine Linux 系统镜像

[![Build Status](https://github.com/dhinSgd/alipne/workflows/Build%20Alpine%20Linux%20Image/badge.svg)](https://github.com/dhinSgd/alipne/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Alpine Linux](https://img.shields.io/badge/Alpine%20Linux-v3.20-0D597F?logo=alpine-linux)](https://alpinelinux.org/)

基于 Alpine Linux 的极小化系统镜像，专为阿里云低配置 ECS 实例设计。

## 目标平台

- **CPU**: 2 核
- **内存**: 0.5 GB
- **硬盘**: 1 GB
- **用途**: 轻量级服务器（SSH 为主）

## 核心特性

- ✓ 极小化系统占用（~80-100 MB）
- ✓ zram 压缩内存（总可用 ~1 GB）
- ✓ btrfs zstd:9 压缩硬盘（2.2-2.5x 压缩比）
- ✓ UEFI/GPT 启动
- ✓ 支持阿里云 cloud-init

## 快速开始

### 构建镜像

```bash
# 一键构建（推荐）
make all

# 或分步构建
make prepare      # 准备宿主机环境
make rootfs       # 构建根文件系统
make bootloader   # 安装 grub
make cleanup      # 精简清理
make pack         # 打包 qcow2
make test         # QEMU 测试
```

### 测试镜像

```bash
make test
# 或手动启动
qemu-system-x86_64 \
    -enable-kvm -m 512 -smp 2 \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -drive file=output/alipne.qcow2,if=virtio \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=net0 \
    -nographic

# SSH 登录测试
ssh -p 2222 root@localhost
# 默认密码: SlimAlpine123
```

## 部署到阿里云

1. 上传 `output/alipne.qcow2` 到 OSS
2. 控制台导入自定义镜像（格式: QCOW2, 启动模式: UEFI）
3. 创建 ECS 实例（2c/0.5g/1g）
4. 通过 SSH key 或默认密码登录

**首次登录后务必修改密码**：
```bash
passwd
```

## 系统架构

```
物理 RAM 0.5G + zram swap 500MB = 总可用 ~1GB
/dev/vda (1G, GPT)
├── vda1: 100MB FAT32 (EFI)
└── vda2: 900MB btrfs (zstd:9, noatime)
    ├── @ → /
    ├── @home → /home
    ├── @var_log → /var/log
    └── @snapshots → /.snapshots
```

## 预装服务

- sshd (OpenSSH)
- chronyd (时间同步)
- cloud-init (云平台支持)
- qemu-guest-agent (虚拟化支持)
- crond (定时任务)

## 项目结构

```
/workspace/alipne/
├── build.sh                 # 主构建脚本
├── Makefile                 # 简化命令
├── config/                  # 配置文件
│   ├── packages.list
│   ├── world
│   └── kernel-modules.list
├── overlay/                 # 覆盖文件
│   └── etc/
├── scripts/                 # 构建脚本
│   ├── 01-prepare-host.sh
│   ├── 02-build-rootfs.sh
│   ├── 03-setup-bootloader.sh
│   ├── 04-cleanup.sh
│   ├── 05-pack-image.sh
│   └── 06-test-image.sh
└── output/                  # 输出目录
    ├── alipne.raw
    └── alipne.qcow2
```

## 技术细节

详见 [设计文档](brainstorm/specs/2026-05-24-alipne-minimal-system-design.md)

## 贡献

欢迎贡献！请查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解如何参与项目。

## 许可证

[MIT License](LICENSE) - 详见 LICENSE 文件

## 致谢

- [Alpine Linux](https://alpinelinux.org/) - 优秀的轻量级 Linux 发行版
- [btrfs](https://btrfs.wiki.kernel.org/) - 现代文件系统
- [zstd](https://github.com/facebook/zstd) - 高效压缩算法

## 联系方式

- 作者: sunxizhen
- GitHub: [dhinSgd/alipne](https://github.com/dhinSgd/alipne)
- Issues: [提交问题](https://github.com/dhinSgd/alipne/issues)
