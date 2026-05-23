# 常见问题解答 (FAQ)

## 构建相关

### Q: 构建需要多长时间？
A: 在现代硬件上，完整构建通常需要 5-15 分钟，具体取决于：
- 网络速度（下载 Alpine 包）
- 磁盘 I/O 性能
- CPU 性能（压缩和清理阶段）

### Q: 可以在非 Ubuntu 系统上构建吗？
A: 可以，但脚本针对 Ubuntu/Debian 优化。其他发行版需要：
- 调整 `01-prepare-host.sh` 中的包管理器命令
- 确保安装了相同的依赖包

### Q: 构建失败如何调试？
A: 
1. 检查是否有 root 权限：`sudo make all`
2. 查看具体失败的步骤输出
3. 手动运行失败的脚本：`sudo bash scripts/XX-xxx.sh`
4. 检查 `/tmp/alipne-*` 目录是否有残留挂载

### Q: 如何修改镜像大小？
A: 编辑 `scripts/02-build-rootfs.sh`：
```bash
IMAGE_SIZE="2G"  # 改为 2GB
```
同时调整 parted 命令中的分区大小。

## 系统配置

### Q: 如何修改默认密码？
A: 编辑 `scripts/02-build-rootfs.sh`，找到：
```bash
echo "root:SlimAlpine123" | chpasswd
```
改为你想要的密码。

### Q: 如何添加更多软件包？
A: 编辑 `config/packages.list`，添加包名（每行一个）。
注意：每个包都会增加镜像大小。

### Q: 如何预装 SSH 密钥？
A: 
```bash
mkdir -p overlay/root/.ssh
cat ~/.ssh/id_rsa.pub > overlay/root/.ssh/authorized_keys
chmod 600 overlay/root/.ssh/authorized_keys
```

### Q: 如何修改 zram 大小？
A: 编辑 `overlay/etc/conf.d/zram-init`：
```bash
size0=500  # 单位 MB，改为 600 或更大
```

### Q: 如何禁用 cloud-init？
A: 编辑 `scripts/02-build-rootfs.sh`，删除以下行：
```bash
rc-update add cloud-init default
rc-update add cloud-init-local default
rc-update add cloud-config default
rc-update add cloud-final default
```

## 部署相关

### Q: 支持哪些云平台？
A: 
- **完全支持**: 阿里云 ECS（已测试）
- **理论支持**: 腾讯云、华为云、AWS、Azure（需要调整 cloud-init 配置）
- **本地虚拟化**: QEMU/KVM, VirtualBox, VMware

### Q: 可以在物理机上安装吗？
A: 可以，但需要：
1. 将 qcow2 转换为 raw：`qemu-img convert -f qcow2 -O raw alipne.qcow2 alipne.img`
2. 使用 dd 写入 U 盘或硬盘：`dd if=alipne.img of=/dev/sdX bs=4M status=progress`
3. 注意：需要 UEFI 启动支持

### Q: 如何扩容磁盘？
A: 在云平台扩容后：
```bash
# 扩展分区
parted /dev/vda resizepart 2 100%

# 扩展 btrfs
btrfs filesystem resize max /
```

### Q: 首次登录后应该做什么？
A: 
1. 修改 root 密码：`passwd`
2. 更新系统：`apk update && apk upgrade`
3. 配置 SSH 密钥认证
4. 设置防火墙规则
5. 创建普通用户

## 性能相关

### Q: 为什么选择 zstd:9 压缩？
A: 
- zstd:9 提供 2.2-2.5x 压缩比
- 解压速度快（~500 MB/s）
- CPU 开销适中（2 核可承受）
- 比 zstd:15 快，比 zstd:3 压缩率高

### Q: 0.5GB 内存够用吗？
A: 
- 空闲状态：~350MB 可用
- 加上 zram：总可用 ~1GB
- 适合：SSH、轻量级 Web 服务、脚本任务
- 不适合：数据库、编译、大型应用

### Q: 如何优化性能？
A: 
1. 调整 swappiness：`sysctl vm.swappiness=80`
2. 增加 zram 大小（如果有更多 RAM）
3. 禁用不需要的服务
4. 使用 tmpfs 存放临时文件

### Q: 启动时间多久？
A: 
- QEMU 测试：~15-20 秒
- 阿里云 ECS：~20-30 秒
- 取决于硬件和网络（cloud-init）

## 安全相关

### Q: 默认密码安全吗？
A: 
**不安全！** 默认密码 `SlimAlpine123` 仅用于首次登录。
**必须**在首次登录后立即修改：`passwd`

### Q: 如何加固安全？
A: 
1. 修改 root 密码
2. 禁用密码登录，仅用 SSH 密钥
3. 配置防火墙（iptables）
4. 定期更新系统
5. 启用 fail2ban（需要安装）
6. 限制 SSH 访问 IP

### Q: cloud-init 会覆盖配置吗？
A: 
部分配置会被覆盖（如 hostname、SSH 密钥）。
如需保留配置，编辑 `/etc/cloud/cloud.cfg` 禁用相应模块。

## 故障排除

### Q: QEMU 测试无法启动
A: 
1. 检查 OVMF 固件：`ls /usr/share/OVMF/OVMF_CODE.fd`
2. 检查 KVM 支持：`lsmod | grep kvm`
3. 尝试不使用 KVM：删除 `-enable-kvm` 参数

### Q: SSH 无法连接
A: 
1. 检查 sshd 服务：`rc-service sshd status`
2. 检查防火墙/安全组
3. 检查 SSH 配置：`cat /etc/ssh/sshd_config`
4. 查看日志：`tail /var/log/messages`

### Q: zram 未启动
A: 
```bash
# 检查服务
rc-service zram-init status

# 手动启动
rc-service zram-init start

# 查看配置
cat /etc/conf.d/zram-init
```

### Q: 磁盘空间不足
A: 
```bash
# 清理 apk 缓存
apk cache clean

# 清理日志
rm -rf /var/log/*.log

# 查找大文件
du -sh /* | sort -h
```

### Q: 内存不足
A: 
```bash
# 检查内存使用
free -h

# 检查 zram
swapon -s

# 重启 zram
rc-service zram-init restart
```

## 高级用法

### Q: 如何添加自定义服务？
A: 
1. 创建服务脚本：`overlay/etc/init.d/myservice`
2. 设置权限：`chmod +x overlay/etc/init.d/myservice`
3. 在构建脚本中添加：`rc-update add myservice default`

### Q: 如何使用不同的 Alpine 版本？
A: 编辑 `scripts/02-build-rootfs.sh`：
```bash
ALPINE_VERSION="v3.19"  # 或其他版本
```

### Q: 如何创建多个镜像变体？
A: 
1. 复制 `config/packages.list` 为 `packages-minimal.list`、`packages-full.list`
2. 修改构建脚本读取不同的配置文件
3. 输出到不同的文件名

### Q: 如何集成 CI/CD？
A: 
```yaml
# GitHub Actions 示例
- name: Build alipne
  run: |
    sudo make all
    
- name: Upload artifact
  uses: actions/upload-artifact@v3
  with:
    name: alipne-image
    path: output/alipne.qcow2
```

## 技术细节

### Q: 为什么使用 btrfs 而不是 ext4？
A: 
- 透明压缩（节省空间）
- 子卷支持（便于快照）
- 写时复制（CoW）
- 在线碎片整理

### Q: 为什么使用 musl 而不是 glibc？
A: 
Alpine Linux 默认使用 musl libc：
- 更小（~1MB vs ~10MB）
- 更快的静态链接
- 更安全（内存安全特性）

### Q: 为什么使用 OpenRC 而不是 systemd？
A: 
Alpine Linux 默认使用 OpenRC：
- 更轻量（~1MB vs ~10MB）
- 启动更快
- 配置更简单
- 依赖更少

### Q: 为什么使用 linux-virt 内核？
A: 
- 专为虚拟化优化
- 移除了物理硬件驱动
- 体积更小（~10MB vs ~50MB）
- 启动更快

## 贡献与支持

### Q: 如何报告问题？
A: 
1. 检查是否已有类似问题
2. 提供详细信息：
   - 构建环境（OS、版本）
   - 错误信息
   - 复现步骤
3. 附上相关日志

### Q: 如何贡献代码？
A: 
1. Fork 项目
2. 创建特性分支
3. 提交 Pull Request
4. 描述改动和测试结果

### Q: 有商业支持吗？
A: 
本项目为开源项目，无官方商业支持。
社区支持通过 Issues 和讨论区提供。
