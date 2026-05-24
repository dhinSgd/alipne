# 在官方 Alpine 系统上手动优化

如果阿里云导入自定义镜像失败，可以使用官方 Alpine Linux 镜像，然后运行优化脚本。

## 方案对比

### 方案 1: 自定义镜像（原方案）
- ✓ 一键部署，开箱即用
- ✓ 完全定制化（btrfs + zstd 压缩）
- ✗ 阿里云导入可能失败
- ✗ 构建复杂

### 方案 2: 官方镜像 + 优化脚本（推荐）
- ✓ 使用阿里云官方 Alpine 镜像，稳定可靠
- ✓ 一键优化脚本，简单快速
- ✓ 不需要 btrfs，使用 ext4 + zram 即可
- ✓ 更灵活，可按需调整
- ✗ 需要手动运行一次脚本

## 快速开始

### 1. 创建 ECS 实例

在阿里云控制台创建 ECS 实例：
- **镜像**: 公共镜像 → Alpine Linux 3.20
- **规格**: 2核 / 0.5GB 内存 / 1GB 系统盘
- **网络**: 分配公网 IP
- **安全组**: 开放 22 端口

### 2. 登录系统

```bash
ssh root@<ECS公网IP>
```

### 3. 运行优化脚本

```bash
# 下载优化脚本
wget https://raw.githubusercontent.com/dhinSgd/alipne/main/alpine-optimize.sh

# 添加执行权限
chmod +x alpine-optimize.sh

# 运行优化（需要 root 权限）
./alpine-optimize.sh
```

### 4. 重启系统

```bash
reboot
```

## 优化内容

优化脚本会自动完成以下操作：

### 1. 配置 zram swap (384MB)
- 使用 zstd 压缩算法
- swappiness=80（适度使用 swap）
- 总可用内存 ~850-900MB

### 2. 清理内核模块
- 删除显卡驱动（GPU, fbdev）
- 删除声卡驱动
- 删除蓝牙模块
- 删除无线网卡驱动
- 删除多媒体设备驱动
- 删除输入设备驱动（键盘/鼠标）
- 删除 virtio_balloon（固定内存不需要）
- 节省 20-40MB 空间

### 3. 系统精简
- 删除文档（man, doc, info）
- 删除本地化文件（保留 en_US）
- 清理 apk 缓存
- 清理临时文件和旧日志

### 4. 优化系统服务
- 禁用不需要的服务（acpid, klogd）
- 确保必要服务启用（chronyd, crond, sshd）

### 5. 配置时区和时间同步
- 时区: Asia/Shanghai
- NTP: 阿里云 NTP 服务器
- 自动时间同步

## 为什么不用 btrfs？

在这个方案中，我们使用 **ext4 + zram** 而不是 **btrfs + zstd**：

### ext4 的优势
- ✓ 更成熟稳定
- ✓ 性能更好（低配置环境）
- ✓ 内存占用更小
- ✓ 阿里云官方镜像默认使用

### zram 的优势
- ✓ 压缩比 ~2.5x（比 btrfs zstd:3 的 ~2.2x 更高）
- ✓ 压缩内存而不是硬盘，更有效
- ✓ 速度快（内存操作 vs 硬盘操作）
- ✓ 对 CPU 压力更小

### 结论
在 0.5GB 内存的环境中，**内存是瓶颈，硬盘不是**。使用 zram 压缩内存比压缩硬盘更有价值。

## 预期效果

优化后的系统：

| 指标 | 优化前 | 优化后 |
|------|--------|--------|
| 系统占用 | ~150MB | ~80-100MB |
| 可用内存 | ~350MB | ~400MB（物理）+ 384MB（zram）= ~750-850MB |
| 内核模块 | ~60MB | ~30-40MB |
| 启动时间 | ~20秒 | ~15秒 |

## 后续配置

优化完成后，建议运行配置脚本进行基础设置：

```bash
# 下载配置脚本
wget https://raw.githubusercontent.com/dhinSgd/alipne/main/alpine-setup.sh
chmod +x alpine-setup.sh

# 运行配置向导
./alpine-setup.sh
```

配置脚本功能：
1. 修改 root SSH 密码
2. 修改 SSH 端口
3. 设置时区并同步时间
4. 查看系统状态

## 安全建议

1. **修改默认密码**
   ```bash
   passwd
   ```

2. **配置 SSH 密钥认证**
   ```bash
   mkdir -p ~/.ssh
   echo "your-public-key" >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

3. **禁用密码登录（可选）**
   ```bash
   vi /etc/ssh/sshd_config
   # 设置: PasswordAuthentication no
   rc-service sshd restart
   ```

4. **配置防火墙**
   ```bash
   apk add iptables iptables-openrc
   
   # 允许 SSH
   iptables -A INPUT -p tcp --dport 22 -j ACCEPT
   iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
   iptables -A INPUT -i lo -j ACCEPT
   iptables -P INPUT DROP
   
   # 保存规则
   /etc/init.d/iptables save
   rc-update add iptables default
   ```

## 常见问题

### Q: 优化脚本安全吗？
A: 脚本会在操作前备份配置文件到 `/root/alpine-optimize-backup-*`，可以随时恢复。

### Q: 可以只执行部分优化吗？
A: 可以，脚本会在关键步骤询问确认。

### Q: 删除内核模块会影响系统吗？
A: 不会，只删除云服务器绝对用不到的硬件驱动（显卡、声卡、蓝牙等）。

### Q: 如何验证优化效果？
A: 运行 `free -h` 查看内存，`df -h` 查看硬盘，`swapon -s` 查看 swap。

### Q: 可以在生产环境使用吗？
A: 建议先在测试环境验证，确认无问题后再用于生产。

## 回滚

如果需要回滚优化：

```bash
# 查看备份目录
ls -la /root/alpine-optimize-backup-*

# 恢复配置文件
cp /root/alpine-optimize-backup-*/fstab /etc/fstab
cp /root/alpine-optimize-backup-*/sysctl.conf /etc/sysctl.conf

# 禁用 zram
rc-update del zram-init boot
rc-service zram-init stop

# 重启
reboot
```

## 技术支持

- GitHub: https://github.com/dhinSgd/alipne
- Issues: https://github.com/dhinSgd/alipne/issues

---

**推荐**: 使用官方 Alpine 镜像 + 优化脚本的方案更稳定可靠！
