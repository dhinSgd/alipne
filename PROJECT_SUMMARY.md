# alipne 项目总结

## 项目概述

**alipne** 是一个基于 Alpine Linux 的极小化系统镜像构建项目，专为阿里云低配置 ECS 实例（2核/0.5GB内存/1GB硬盘）设计。

## 核心目标

1. **极小化占用**: 系统占用 < 100MB，为应用留出最大空间
2. **内存优化**: 使用 zram 压缩，总可用内存 ~1GB
3. **存储优化**: btrfs + zstd:9 压缩，2.2-2.5x 压缩比
4. **快速启动**: UEFI 启动，< 30 秒进入系统
5. **云原生**: 完整 cloud-init 支持

## 技术栈

| 组件 | 选择 | 原因 |
|------|------|------|
| 发行版 | Alpine Linux v3.20 | 最小化、musl libc、安全 |
| 内核 | linux-virt | 虚拟化优化、体积小 |
| Init | OpenRC | 轻量、快速 |
| 文件系统 | btrfs | 透明压缩、子卷、快照 |
| 压缩算法 | zstd:9 | 高压缩比、快速解压 |
| 内存管理 | zram | CPU 换内存、2.5x 压缩 |
| 启动方式 | UEFI/GPT | 现代标准 |
| 镜像格式 | QCOW2 | 云平台标准、支持压缩 |

## 项目结构

```
/workspace/alipne/
├── build.sh                    # 主构建脚本
├── Makefile                    # 简化命令
├── verify.sh                   # 系统验证脚本
│
├── config/                     # 配置文件
│   ├── packages.list           # 软件包列表
│   ├── world                   # Alpine world 文件
│   └── kernel-modules.list     # 内核模块白名单
│
├── overlay/                    # 覆盖文件系统
│   └── etc/
│       ├── fstab               # 文件系统挂载表
│       ├── resolv.conf         # DNS 配置
│       ├── ssh/sshd_config     # SSH 配置
│       ├── network/interfaces  # 网络配置
│       ├── conf.d/zram-init    # zram 配置
│       ├── sysctl.d/99-zram.conf  # 内核参数
│       └── cloud/              # cloud-init 配置
│
├── scripts/                    # 构建脚本
│   ├── 01-prepare-host.sh      # 准备宿主机
│   ├── 02-build-rootfs.sh      # 构建根文件系统
│   ├── 03-setup-bootloader.sh  # 安装 grub
│   ├── 04-cleanup.sh           # 精简清理
│   ├── 05-pack-image.sh        # 打包 qcow2
│   └── 06-test-image.sh        # QEMU 测试
│
├── output/                     # 输出目录
│   ├── alipne.raw              # 原始镜像
│   └── alipne.qcow2            # 最终镜像
│
└── docs/                       # 文档
    ├── README.md               # 项目说明
    ├── BUILD.md                # 构建指南
    ├── DEPLOY.md               # 部署指南
    ├── FAQ.md                  # 常见问题
    └── CHANGELOG.md            # 更新日志
```

## 构建流程

```
1. 准备宿主机环境
   ├── 安装构建依赖（qemu, btrfs-progs, parted 等）
   └── 下载 alpine-make-vm-image

2. 构建根文件系统
   ├── 创建 1GB raw 镜像
   ├── 创建 GPT 分区表（EFI 100MB + btrfs 900MB）
   ├── 格式化分区（FAT32 + btrfs）
   ├── 创建 btrfs 子卷（@, @home, @var_log, @snapshots）
   ├── 安装 Alpine Linux 基础系统
   ├── 安装软件包（从 packages.list）
   ├── 应用 overlay 配置文件
   ├── 配置系统（主机名、密码、服务）
   └── 更新 fstab UUID

3. 安装引导加载器
   ├── 挂载镜像和虚拟文件系统
   ├── chroot 安装 grub-efi
   └── 生成 grub.cfg

4. 精简清理
   ├── 删除文档和本地化文件
   ├── 清理 apk 缓存
   ├── 精简内核模块（仅保留 virtio）
   └── btrfs 碎片整理和重新压缩

5. 打包镜像
   └── 转换 raw -> qcow2（zstd 压缩）

6. 测试验证
   ├── QEMU 启动测试
   └── 运行验证脚本
```

## 系统架构

```
┌─────────────────────────────────────────────────┐
│  阿里云 ECS (2c / 0.5G RAM / 1G Disk)           │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │  Alpine Linux v3.20 (linux-virt)           │ │
│  │  Init: OpenRC  |  libc: musl               │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  内存层:                                         │
│  ┌──────────────┐  ┌──────────────┐            │
│  │ 物理 RAM     │  │ zram swap    │            │
│  │ 512 MB       │  │ 500 MB       │            │
│  │              │  │ (zstd, 2.5x) │            │
│  └──────────────┘  └──────────────┘            │
│  总可用: ~1 GB                                  │
│                                                  │
│  存储层:                                         │
│  /dev/vda (1G, GPT)                             │
│  ├─ vda1: 100MB FAT32 (EFI)                    │
│  └─ vda2: 900MB btrfs (zstd:9, noatime)        │
│     ├─ @ → /                                    │
│     ├─ @home → /home                            │
│     ├─ @var_log → /var/log                     │
│     └─ @snapshots → /.snapshots                │
│                                                  │
│  服务层:                                         │
│  ├─ sshd (OpenSSH)                              │
│  ├─ chronyd (时间同步)                          │
│  ├─ crond (定时任务)                            │
│  ├─ qemu-guest-agent (虚拟化支持)              │
│  └─ cloud-init (云平台集成)                    │
└─────────────────────────────────────────────────┘
```

## 关键特性

### 1. 极小化系统
- 系统占用: ~80-100 MB
- 可用空间: ~800 MB
- 镜像大小: ~120-180 MB (qcow2)

### 2. 内存优化
- 物理 RAM: 512 MB
- zram swap: 500 MB (zstd 压缩)
- 压缩比: ~2.5x
- 总可用: ~1 GB

### 3. 存储优化
- btrfs 透明压缩 (zstd:9)
- 压缩比: ~2.2-2.5x
- noatime 减少写入
- 子卷支持快照

### 4. 快速启动
- UEFI 启动
- 精简内核模块
- 最小化服务
- 启动时间: < 30 秒

### 5. 云原生
- cloud-init 支持
- 阿里云数据源
- 自动注入 SSH 密钥
- 网络自动配置

## 预估指标

| 指标 | 预估值 | 实际值 |
|------|--------|--------|
| 系统占用 | ~80-100 MB | 待测试 |
| 可用空间 | ~800 MB | 待测试 |
| 总可用内存 | ~1 GB | 待测试 |
| QCOW2 大小 | ~120-180 MB | 待测试 |
| 启动时间 | < 30 秒 | 待测试 |
| btrfs 压缩比 | ~2.2-2.5x | 待测试 |
| zram 压缩比 | ~2.5x | 待测试 |

## 使用场景

### 适合
- ✓ SSH 跳板机
- ✓ 轻量级 Web 服务
- ✓ 反向代理（nginx, caddy）
- ✓ 定时任务执行
- ✓ 监控 agent
- ✓ 开发测试环境

### 不适合
- ✗ 数据库服务器
- ✗ 编译构建
- ✗ 大型应用
- ✗ 高并发服务
- ✗ 内存密集型任务

## 安全考虑

### 默认配置
- ⚠️ root 密码登录启用（默认: SlimAlpine123）
- ⚠️ SSH 密码认证启用
- ✓ 防火墙未配置（需手动设置）

### 建议加固
1. 首次登录后立即修改密码
2. 配置 SSH 密钥认证
3. 禁用密码登录
4. 配置 iptables 防火墙
5. 定期更新系统
6. 限制 SSH 访问 IP

## 后续计划

### 短期
- [ ] 完成构建和测试
- [ ] 验证所有功能
- [ ] 优化镜像大小
- [ ] 完善文档

### 中期
- [ ] 支持更多云平台（腾讯云、华为云）
- [ ] 提供多个镜像变体（minimal, standard, full）
- [ ] 自动化 CI/CD 构建
- [ ] 性能基准测试

### 长期
- [ ] 支持 ARM 架构
- [ ] 容器化支持（Docker, Podman）
- [ ] 集群部署工具
- [ ] Web 管理界面

## 贡献指南

欢迎贡献！请参考：
1. Fork 项目
2. 创建特性分支
3. 提交 Pull Request
4. 遵循代码规范
5. 添加测试和文档

## 许可证

MIT License

## 联系方式

- 作者: sunxizhen + Claude
- 项目: /workspace/alipne
- 日期: 2026-05-24

---

**注意**: 本项目仍在开发中，请在生产环境使用前充分测试。
