# 构建环境说明

## 当前状态

项目代码已完成并推送到 Git 仓库：
- ✅ 完整的构建脚本系统
- ✅ 配置文件和 overlay 系统
- ✅ 详细文档
- ✅ 已推送到 `git@codeup.aliyun.com:68fa4149bb64aae551966922/simply-cloud-alpine.git`

## 构建环境限制

当前在 Docker 容器中运行，遇到以下限制：

### 问题
- 容器中无法访问 `/dev/loop*` 设备节点
- `losetup` 命令无法找到可用的 loop 设备
- 虽然内核支持 loop 设备，但容器的 devtmpfs 不允许创建设备节点

### 原因
这是 Docker 容器的标准安全限制，即使容器有 `CAP_SYS_ADMIN` 和 `CAP_MKNOD` 权限，也无法在运行时创建块设备节点。

## 解决方案

### 方案 1: 在宿主机上构建（推荐）

```bash
# 克隆仓库
git clone git@codeup.aliyun.com:68fa4149bb64aae551966922/simply-cloud-alpine.git
cd simply-cloud-alpine

# 在真实的 Ubuntu 系统上构建
sudo make all

# 测试
make test
```

### 方案 2: 使用特权容器

启动容器时添加必要的权限：

```bash
docker run --privileged \
  --device=/dev/loop0 \
  --device=/dev/loop1 \
  --device=/dev/loop2 \
  --device=/dev/loop3 \
  --device=/dev/loop4 \
  --device=/dev/loop5 \
  --device=/dev/loop6 \
  --device=/dev/loop7 \
  -v /workspace:/workspace \
  ubuntu:24.04
```

或者使用 `--device-cgroup-rule='b 7:* rmw'` 允许访问所有 loop 设备。

### 方案 3: 在虚拟机中构建

使用完整的 Ubuntu 虚拟机（如 VirtualBox、VMware、KVM）而不是容器。

### 方案 4: 使用 GitHub Actions / GitLab CI

在 CI/CD 环境中构建，这些环境通常支持特权模式：

```yaml
# .github/workflows/build.yml
name: Build alipne Image

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Build image
      run: |
        sudo make all
    
    - name: Upload artifact
      uses: actions/upload-artifact@v3
      with:
        name: alipne-image
        path: output/alipne.qcow2
```

## 技术细节

### 为什么需要 loop 设备？

构建脚本需要：
1. 创建原始磁盘镜像文件（1GB）
2. 使用 `losetup` 将镜像文件挂载为块设备
3. 使用 `parted` 创建分区
4. 格式化分区（FAT32 + btrfs）
5. 挂载分区并安装系统

这些操作都需要 loop 设备支持。

### 检查环境是否支持

```bash
# 检查 loop 设备
ls -la /dev/loop*

# 测试 losetup
losetup -f

# 如果以上命令成功，说明环境支持构建
```

## 下一步

1. **选择合适的构建环境**（见上述方案）
2. **克隆仓库**
3. **运行构建**: `sudo make all`
4. **测试镜像**: `make test`
5. **部署到阿里云**（参考 DEPLOY.md）

## 项目文件完整性

所有必需的文件都已创建并提交：

```
✓ 构建脚本 (6 个)
✓ 配置文件
✓ Overlay 文件系统
✓ 文档 (7 个)
✓ Makefile
✓ 验证脚本
```

项目已准备就绪，只需要在支持 loop 设备的环境中执行构建即可。
