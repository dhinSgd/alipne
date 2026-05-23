# GitHub 仓库设置指南

本文档说明如何在 GitHub 上创建公开仓库并配置 CI/CD。

## 步骤 1: 创建 GitHub 仓库

1. 访问 [GitHub](https://github.com)
2. 点击右上角的 "+" → "New repository"
3. 填写仓库信息：
   - **Repository name**: `alipne`
   - **Description**: `极简 Alpine Linux 系统镜像 - 专为阿里云低配置 ECS 设计`
   - **Visibility**: ✅ Public（公开）
   - **Initialize**: ❌ 不要勾选任何初始化选项（我们已有代码）

4. 点击 "Create repository"

## 步骤 2: 推送代码到 GitHub

```bash
cd /workspace/alipne

# 添加 GitHub 远程仓库
git remote add github https://github.com/YOUR_USERNAME/alipne.git

# 或使用 SSH（推荐）
git remote add github git@github.com:YOUR_USERNAME/alipne.git

# 推送代码
git push github main
```

## 步骤 3: 配置仓库设置

### 3.1 启用 GitHub Actions

1. 进入仓库页面
2. 点击 "Settings" → "Actions" → "General"
3. 确保 "Allow all actions and reusable workflows" 已选中
4. 保存设置

### 3.2 配置 GitHub Pages（可选）

1. 点击 "Settings" → "Pages"
2. Source: Deploy from a branch
3. Branch: main / (root)
4. 保存

### 3.3 添加仓库主题和标签

1. 在仓库主页点击 "⚙️" (About 旁边)
2. 添加描述：`极简 Alpine Linux 系统镜像 - 专为阿里云低配置 ECS 设计`
3. 添加标签：
   - `alpine-linux`
   - `cloud-image`
   - `minimal`
   - `aliyun`
   - `ecs`
   - `btrfs`
   - `zram`
   - `qcow2`
4. 保存

### 3.4 启用 Discussions（可选）

1. 点击 "Settings" → "General"
2. 向下滚动到 "Features"
3. 勾选 "Discussions"
4. 保存

## 步骤 4: 触发首次构建

推送代码后，GitHub Actions 会自动触发构建：

1. 进入仓库页面
2. 点击 "Actions" 标签
3. 查看 "Build Alpine Linux Image" 工作流
4. 等待构建完成（约 10-15 分钟）

## 步骤 5: 查看构建产物

构建完成后：

1. 在 Actions 页面点击完成的工作流
2. 向下滚动到 "Artifacts"
3. 下载 `alipne-image` (包含 alipne.qcow2)

## 步骤 6: 自动发布 Release

当推送到 main 分支时，会自动创建 Release：

1. 进入仓库页面
2. 点击 "Releases"
3. 查看自动创建的 Release
4. 下载 `alipne.qcow2` 镜像文件

## 步骤 7: 更新 README 中的链接

编辑 `README.md`，将 `YOUR_USERNAME` 替换为你的 GitHub 用户名：

```bash
sed -i 's/YOUR_USERNAME/你的用户名/g' README.md
git add README.md
git commit -m "docs: 更新 GitHub 用户名"
git push github main
```

## 工作流说明

### 触发条件

- 推送到 `main` 或 `develop` 分支
- 创建针对 `main` 分支的 Pull Request
- 手动触发（在 Actions 页面点击 "Run workflow"）

### 构建步骤

1. ✅ 检出代码
2. ✅ 清理磁盘空间
3. ✅ 准备构建环境
4. ✅ 构建根文件系统
5. ✅ 安装引导加载器
6. ✅ 清理和优化
7. ✅ 打包镜像
8. ✅ 上传构建产物
9. ✅ 创建 Release（仅 main 分支）

### 构建产物

- **Artifact**: 保留 30 天，可在 Actions 页面下载
- **Release**: 永久保存，包含版本标签

## 徽章

在 README.md 中已添加以下徽章：

- [![Build Status](https://github.com/YOUR_USERNAME/alipne/workflows/Build%20Alpine%20Linux%20Image/badge.svg)](https://github.com/YOUR_USERNAME/alipne/actions)
- [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
- [![Alpine Linux](https://img.shields.io/badge/Alpine%20Linux-v3.20-0D597F?logo=alpine-linux)](https://alpinelinux.org/)

记得替换 `YOUR_USERNAME`！

## 故障排除

### 构建失败

1. 查看 Actions 日志
2. 检查是否有权限问题
3. 确认 GitHub Actions 已启用

### 无法推送

```bash
# 检查远程仓库
git remote -v

# 如果需要，更新远程 URL
git remote set-url github git@github.com:YOUR_USERNAME/alipne.git
```

### Release 未创建

- 确认推送到了 `main` 分支
- 检查 `GITHUB_TOKEN` 权限
- 查看 Actions 日志中的错误信息

## 下一步

1. ✅ 创建 GitHub 仓库
2. ✅ 推送代码
3. ✅ 等待首次构建完成
4. ✅ 下载镜像文件
5. ✅ 部署到阿里云（参考 DEPLOY.md）

---

**注意**: 记得在所有文档中将 `YOUR_USERNAME` 替换为你的实际 GitHub 用户名！
