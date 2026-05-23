# 更新日志

本文档记录 alipne 项目的所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [未发布]

### 新增
- 初始项目结构
- 完整的构建脚本（6 个阶段）
- Makefile 简化命令
- overlay 配置文件系统
- QEMU 测试支持
- 系统验证脚本
- 详细文档（README, BUILD, DEPLOY, FAQ）

### 特性
- Alpine Linux v3.20 基础系统
- UEFI/GPT 启动支持
- btrfs 文件系统 + zstd:3 压缩
- zram 内存压缩（500MB）
- 子卷布局（@, @home, @var_log, @snapshots）
- cloud-init 阿里云支持
- 预配置服务（sshd, chronyd, crond, qemu-guest-agent）
- 极小化系统占用（~80-100 MB）

### 配置
- SSH 允许 root 密码登录（默认密码: SlimAlpine123）
- DNS: DHCP 优先，回退到 Cloudflare + Google
- swappiness=100（优先使用 zram）
- noatime 挂载选项（减少写入）

## [0.1.0] - 2026-05-24

### 新增
- 项目初始化
- 设计文档完成
- 基础架构确定

---

## 版本说明

### 版本号格式
- **主版本号**: 不兼容的 API 变更
- **次版本号**: 向下兼容的功能新增
- **修订号**: 向下兼容的问题修正

### 发布周期
- 稳定版本：根据需求发布
- 开发版本：持续更新

### 支持策略
- 最新稳定版：完全支持
- 前一个稳定版：安全更新
- 更早版本：不再支持
