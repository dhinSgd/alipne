# alipne 构建指南

## 系统要求

- **操作系统**: Ubuntu 20.04+ 或 Debian 11+
- **权限**: root 或 sudo
- **磁盘空间**: 至少 5 GB 可用空间
- **内存**: 建议 2 GB+

## 快速开始

### 1. 克隆项目

```bash
cd /workspace/alipne
```

### 2. 一键构建

```bash
sudo make all
```

这将自动执行以下步骤：
1. 安装构建依赖
2. 创建并格式化镜像
3. 安装 Alpine Linux
4. 配置系统
5. 安装 grub
6. 精简清理
7. 打包成 qcow2

### 3. 测试镜像

```bash
make test
```

在 QEMU 中启动虚拟机，验证系统是否正常工作。

## 分步构建

如果需要更细粒度的控制，可以分步执行：

```bash
sudo make prepare      # 准备宿主机环境
sudo make rootfs       # 构建根文件系统
sudo make bootloader   # 安装 grub
sudo make cleanup      # 精简清理
sudo make pack         # 打包 qcow2
make test              # 测试（不需要 root）
```

## 自定义配置

### 修改软件包列表

编辑 `config/packages.list`，添加或删除需要的包：

```bash
nano config/packages.list
```

### 修改系统配置

编辑 `overlay/etc/` 下的配置文件：

- `overlay/etc/fstab` - 文件系统挂载
- `overlay/etc/ssh/sshd_config` - SSH 配置
- `overlay/etc/conf.d/zram-init` - zram 配置
- `overlay/etc/sysctl.d/99-zram.conf` - 内核参数

### 修改分区大小

编辑 `scripts/02-build-rootfs.sh`，修改以下变量：

```bash
IMAGE_SIZE="1G"  # 总镜像大小
```

以及 parted 命令中的分区大小。

## 验证清单

构建完成后，使用 `make test` 启动虚拟机，验证以下项目：

### 启动验证
- [ ] UEFI 启动成功
- [ ] grub 菜单正常
- [ ] 内核加载成功
- [ ] 启动时间 < 30 秒

### SSH 验证
```bash
# 在另一个终端
ssh -p 2222 root@localhost
# 密码: SlimAlpine123
```

### zram 验证
```bash
swapon -s
# 应显示 /dev/zram0 (500MB, zstd)

cat /proc/sys/vm/swappiness
# 应显示 100
```

### btrfs 验证
```bash
mount | grep btrfs
# 应显示 compress=zstd:3, noatime

btrfs subvolume list /
# 应显示 @, @home, @var_log 子卷
```

### 系统占用验证
```bash
df -h /
# 根分区使用应 < 100MB

free -h
# 系统空闲内存应 > 350MB
```

### 服务验证
```bash
rc-status
# 检查 sshd, chronyd, qemu-guest-agent, cloud-init 是否运行
```

### 网络验证
```bash
ping -c 3 1.1.1.1
cat /etc/resolv.conf
# 应显示 Cloudflare + Google DNS
```

## 故障排除

### 构建失败

**问题**: 权限不足
```bash
# 解决: 使用 sudo
sudo make all
```

**问题**: loop 设备不可用
```bash
# 解决: 加载 loop 模块
sudo modprobe loop
```

**问题**: 分区设备未出现
```bash
# 解决: 使用 kpartx
sudo apt-get install kpartx
```

### QEMU 测试失败

**问题**: OVMF 固件未找到
```bash
# 解决: 安装 ovmf
sudo apt-get install ovmf
```

**问题**: KVM 不可用
```bash
# 解决: 检查虚拟化支持
egrep -c '(vmx|svm)' /proc/cpuinfo
# 如果输出 0，说明 CPU 不支持虚拟化或未在 BIOS 中启用
```

### 启动失败

**问题**: grub 找不到内核
```bash
# 解决: 检查 /boot 目录是否有内核文件
# 重新运行 make bootloader
```

**问题**: 无法挂载根文件系统
```bash
# 解决: 检查 /etc/fstab 中的 UUID 是否正确
# 重新运行 make rootfs
```

## 清理

删除构建产物：

```bash
make clean
```

这将删除：
- `output/alipne.raw`
- `output/alipne.qcow2`
- 临时挂载点

## 高级用法

### 修改 Alpine 版本

编辑 `scripts/02-build-rootfs.sh`：

```bash
ALPINE_VERSION="v3.20"  # 修改为其他版本
```

### 添加自定义脚本

在 `overlay/etc/local.d/` 下添加启动脚本：

```bash
# 创建脚本
cat > overlay/etc/local.d/custom.start <<'EOF'
#!/bin/sh
# 自定义启动脚本
echo "Custom script executed"
EOF

# 设置权限
chmod +x overlay/etc/local.d/custom.start
```

### 预装 SSH 密钥

```bash
# 将公钥添加到 overlay
mkdir -p overlay/root/.ssh
cat ~/.ssh/id_rsa.pub > overlay/root/.ssh/authorized_keys
chmod 600 overlay/root/.ssh/authorized_keys
```

## 部署到阿里云

详见 [部署指南](DEPLOY.md)
