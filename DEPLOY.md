# 阿里云部署指南

本指南介绍如何将构建好的 alipne 镜像部署到阿里云 ECS。

## 前置条件

- 已构建完成的 `output/alipne.qcow2` 镜像
- 阿里云账号
- 已创建 OSS Bucket（与目标 ECS 同地域）
- 已安装阿里云 CLI（可选，用于命令行操作）

## 部署步骤

### 1. 上传镜像到 OSS

#### 方法 A: 使用阿里云控制台

1. 登录 [阿里云 OSS 控制台](https://oss.console.aliyun.com/)
2. 选择或创建一个 Bucket（建议与目标 ECS 同地域）
3. 点击"上传文件"
4. 选择 `output/alipne.qcow2`
5. 等待上传完成

#### 方法 B: 使用 ossutil

```bash
# 安装 ossutil
wget http://gosspublic.alicdn.com/ossutil/1.7.15/ossutil64
chmod +x ossutil64
sudo mv ossutil64 /usr/local/bin/ossutil

# 配置
ossutil config

# 上传
ossutil cp output/alipne.qcow2 oss://your-bucket-name/alipne.qcow2
```

### 2. 导入自定义镜像

#### 使用控制台

1. 登录 [ECS 控制台](https://ecs.console.aliyun.com/)
2. 左侧菜单选择"镜像" → "自定义镜像"
3. 点击"导入镜像"
4. 填写信息：
   - **镜像名称**: alipne-minimal
   - **OSS Object 地址**: 选择刚上传的 qcow2 文件
   - **操作系统**: Linux
   - **系统盘大小**: 1 GiB
   - **系统架构**: x86_64
   - **启动模式**: UEFI
   - **镜像格式**: QCOW2
   - **镜像描述**: 极简 Alpine Linux 系统
5. 点击"确定"
6. 等待导入完成（通常 5-15 分钟）

#### 使用 CLI

```bash
# 安装阿里云 CLI
# https://help.aliyun.com/document_detail/121541.html

# 导入镜像
aliyun ecs ImportImage \
  --RegionId cn-hangzhou \
  --ImageName alipne-minimal \
  --OSType Linux \
  --Architecture x86_64 \
  --Platform "Customized Linux" \
  --BootMode UEFI \
  --DiskDeviceMapping.1.Format qcow2 \
  --DiskDeviceMapping.1.OSSBucket your-bucket-name \
  --DiskDeviceMapping.1.OSSObject alipne.qcow2 \
  --DiskDeviceMapping.1.DiskImageSize 1
```

### 3. 创建 ECS 实例

1. 在 ECS 控制台点击"创建实例"
2. 选择配置：
   - **地域**: 与镜像同地域
   - **实例规格**: ecs.t5-lc1m0.5g（2核 0.5GB）或更高
   - **镜像**: 自定义镜像 → 选择 alipne-minimal
   - **存储**: 系统盘 1 GB（或更大）
   - **网络**: 分配公网 IP
   - **安全组**: 允许 SSH (22 端口)
3. 设置登录凭证：
   - **方式 1**: 上传 SSH 密钥（推荐）
   - **方式 2**: 使用默认密码 `alipne123`（首次登录后立即修改）
4. 点击"创建"

### 4. 首次登录

#### 使用 SSH 密钥（推荐）

```bash
ssh root@<ECS公网IP>
```

#### 使用密码

```bash
ssh root@<ECS公网IP>
# 密码: alipne123

# 立即修改密码
passwd
```

### 5. 验证系统

登录后执行以下命令验证：

```bash
# 检查系统信息
cat /etc/os-release
uname -a

# 检查 zram
swapon -s
free -h

# 检查磁盘
df -h
mount | grep btrfs

# 检查服务
rc-status

# 检查网络
ping -c 3 1.1.1.1
cat /etc/resolv.conf
```

## 安全加固

首次登录后建议执行以下操作：

### 1. 修改 root 密码

```bash
passwd
```

### 2. 创建普通用户

```bash
adduser -s /bin/ash myuser
adduser myuser wheel
```

### 3. 配置 SSH 密钥认证

```bash
# 在本地生成密钥对（如果还没有）
ssh-keygen -t ed25519

# 上传公钥到服务器
ssh-copy-id root@<ECS公网IP>

# 或手动添加
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "your-public-key" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 4. 禁用密码登录（可选）

```bash
# 编辑 SSH 配置
nano /etc/ssh/sshd_config

# 修改以下行
PasswordAuthentication no

# 重启 SSH 服务
rc-service sshd restart
```

### 5. 配置防火墙

```bash
# 安装 iptables
apk add iptables

# 基本规则
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -j DROP

# 保存规则
rc-update add iptables
/etc/init.d/iptables save
```

## 监控与维护

### 查看系统资源

```bash
# 内存使用
free -h

# 磁盘使用
df -h
btrfs filesystem usage /

# CPU 负载
top
```

### 更新系统

```bash
# 更新包索引
apk update

# 升级所有包
apk upgrade

# 清理缓存
apk cache clean
```

### 创建快照

```bash
# btrfs 快照
btrfs subvolume snapshot / /.snapshots/root-$(date +%Y%m%d)
btrfs subvolume snapshot /home /.snapshots/home-$(date +%Y%m%d)
```

### 查看日志

```bash
# 系统日志
tail -f /var/log/messages

# SSH 日志
tail -f /var/log/auth.log
```

## 故障排除

### 无法 SSH 连接

1. 检查安全组规则是否允许 22 端口
2. 检查 ECS 是否有公网 IP
3. 使用 VNC 登录检查 sshd 服务状态：
   ```bash
   rc-service sshd status
   rc-service sshd restart
   ```

### 磁盘空间不足

```bash
# 清理日志
rm -rf /var/log/*.log
journalctl --vacuum-size=10M

# 清理 apk 缓存
apk cache clean

# 检查大文件
du -sh /* | sort -h
```

### 内存不足

```bash
# 检查 zram 状态
swapon -s
zramctl

# 重启 zram
rc-service zram-init restart
```

### cloud-init 问题

```bash
# 查看 cloud-init 日志
cat /var/log/cloud-init.log
cat /var/log/cloud-init-output.log

# 重新运行 cloud-init
cloud-init clean
cloud-init init
```

## 性能优化

### 调整 zram 大小

```bash
# 编辑配置
nano /etc/conf.d/zram-init

# 修改 size0（单位 MB）
size0=500  # 改为 600 或更大

# 重启服务
rc-service zram-init restart
```

### 调整 swappiness

```bash
# 临时修改
sysctl vm.swappiness=80

# 永久修改
echo "vm.swappiness=80" >> /etc/sysctl.d/99-zram.conf
```

### 启用 btrfs 压缩

```bash
# 对现有文件重新压缩
btrfs filesystem defragment -r -czstd /
```

## 扩容

如果需要更大的磁盘空间：

### 在阿里云控制台扩容

1. 停止 ECS 实例
2. 扩容系统盘（如 1GB → 5GB）
3. 启动实例

### 扩展分区和文件系统

```bash
# 扩展分区
parted /dev/vda resizepart 2 100%

# 扩展 btrfs
btrfs filesystem resize max /
```

## 备份与恢复

### 创建镜像备份

1. 在 ECS 控制台选择实例
2. 点击"创建自定义镜像"
3. 填写镜像名称
4. 等待创建完成

### 导出镜像

1. 在镜像列表中选择镜像
2. 点击"导出镜像"
3. 选择 OSS Bucket
4. 下载到本地

## 成本优化

- 使用按量付费实例进行测试
- 确认稳定后转为包年包月
- 使用抢占式实例降低成本（适合非关键业务）
- 及时释放不用的实例和镜像

## 参考链接

- [阿里云 ECS 文档](https://help.aliyun.com/product/25365.html)
- [导入自定义镜像](https://help.aliyun.com/document_detail/25464.html)
- [cloud-init 配置](https://cloudinit.readthedocs.io/)
