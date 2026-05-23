# 快速开始指南

5 分钟快速构建和部署 alipne 镜像。

## 前置条件

- Ubuntu 20.04+ 或 Debian 11+
- root 权限
- 至少 5 GB 可用磁盘空间

## 步骤 1: 构建镜像

```bash
cd /workspace/alipne

# 一键构建（需要 root 权限）
sudo make all
```

构建过程约 5-15 分钟，完成后会生成 `output/alipne.qcow2`。

## 步骤 2: 测试镜像

```bash
# 启动 QEMU 测试
make test
```

等待系统启动（约 20 秒），然后在另一个终端：

```bash
# SSH 登录测试
ssh -p 2222 root@localhost
# 密码: alipne123
```

验证系统：

```bash
# 检查系统信息
cat /etc/os-release
free -h
df -h

# 检查 zram
swapon -s

# 检查服务
rc-status

# 退出
exit
```

按 `Ctrl+A` 然后按 `X` 退出 QEMU。

## 步骤 3: 部署到阿里云

### 3.1 上传镜像

```bash
# 安装 ossutil
wget http://gosspublic.alicdn.com/ossutil/1.7.15/ossutil64
chmod +x ossutil64
sudo mv ossutil64 /usr/local/bin/ossutil

# 配置（输入 AccessKey ID/Secret 和 Endpoint）
ossutil config

# 上传
ossutil cp output/alipne.qcow2 oss://your-bucket/alipne.qcow2
```

### 3.2 导入镜像

1. 登录 [阿里云 ECS 控制台](https://ecs.console.aliyun.com/)
2. 左侧菜单: 镜像 → 自定义镜像 → 导入镜像
3. 填写信息:
   - 镜像名称: `alipne-minimal`
   - OSS Object: 选择刚上传的文件
   - 操作系统: `Linux`
   - 系统盘大小: `1 GiB`
   - 架构: `x86_64`
   - 启动模式: `UEFI`
   - 镜像格式: `QCOW2`
4. 点击"确定"，等待导入完成（5-15 分钟）

### 3.3 创建实例

1. 点击"创建实例"
2. 选择配置:
   - 镜像: 自定义镜像 → `alipne-minimal`
   - 实例规格: `ecs.t5-lc1m0.5g` 或更高
   - 系统盘: 1 GB 或更大
   - 网络: 分配公网 IP
   - 安全组: 允许 SSH (22)
3. 设置 SSH 密钥或使用默认密码
4. 创建实例

### 3.4 登录实例

```bash
# 使用 SSH 密钥
ssh root@<ECS公网IP>

# 或使用密码
ssh root@<ECS公网IP>
# 密码: alipne123
```

### 3.5 首次配置

```bash
# 1. 修改密码（重要！）
passwd

# 2. 更新系统
apk update
apk upgrade

# 3. 验证系统
./verify.sh  # 如果上传了验证脚本

# 4. 配置防火墙（可选）
apk add iptables
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -j DROP
/etc/init.d/iptables save
rc-update add iptables
```

## 完成！

现在你有一个运行中的极简 Alpine Linux 系统，占用不到 100MB，总可用内存约 1GB。

## 下一步

- 阅读 [BUILD.md](BUILD.md) 了解构建细节
- 阅读 [DEPLOY.md](DEPLOY.md) 了解部署选项
- 阅读 [FAQ.md](FAQ.md) 解决常见问题

## 故障排除

### 构建失败

```bash
# 检查权限
sudo make all

# 清理后重试
make clean
sudo make all
```

### 测试失败

```bash
# 检查 OVMF
ls /usr/share/OVMF/OVMF_CODE.fd

# 安装 OVMF
sudo apt-get install ovmf
```

### SSH 无法连接

```bash
# 检查安全组是否允许 22 端口
# 检查 ECS 是否有公网 IP
# 使用 VNC 登录检查 sshd 服务
```

## 获取帮助

- 查看 [FAQ.md](FAQ.md)
- 查看详细文档
- 提交 Issue
