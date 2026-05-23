# Contributing to alipne

感谢你对 alipne 项目的关注！我们欢迎各种形式的贡献。

## 如何贡献

### 报告问题

如果你发现了 bug 或有功能建议：

1. 检查 [Issues](https://github.com/YOUR_USERNAME/alipne/issues) 是否已有相关问题
2. 如果没有，创建新 Issue，包含：
   - 清晰的标题
   - 详细的描述
   - 复现步骤（如果是 bug）
   - 期望的行为
   - 实际的行为
   - 环境信息（OS、版本等）

### 提交代码

1. **Fork 仓库**
   ```bash
   # 在 GitHub 上点击 Fork 按钮
   ```

2. **克隆你的 Fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/alipne.git
   cd alipne
   ```

3. **创建特性分支**
   ```bash
   git checkout -b feature/your-feature-name
   # 或
   git checkout -b fix/your-bug-fix
   ```

4. **进行修改**
   - 遵循现有的代码风格
   - 添加必要的注释
   - 更新相关文档

5. **测试你的修改**
   ```bash
   sudo make all
   make test
   ```

6. **提交修改**
   ```bash
   git add .
   git commit -m "feat: 添加新功能描述"
   # 或
   git commit -m "fix: 修复某个问题"
   ```

   提交信息格式：
   - `feat:` 新功能
   - `fix:` Bug 修复
   - `docs:` 文档更新
   - `style:` 代码格式调整
   - `refactor:` 重构
   - `test:` 测试相关
   - `chore:` 构建/工具相关

7. **推送到你的 Fork**
   ```bash
   git push origin feature/your-feature-name
   ```

8. **创建 Pull Request**
   - 在 GitHub 上打开你的 Fork
   - 点击 "New Pull Request"
   - 填写 PR 描述，说明：
     - 做了什么改动
     - 为什么要这样改
     - 如何测试
     - 相关的 Issue（如果有）

## 代码规范

### Shell 脚本

- 使用 `#!/bin/bash` 作为 shebang
- 使用 `set -e` 在脚本开头
- 变量使用大写字母和下划线
- 函数使用小写字母和下划线
- 添加必要的注释

示例：
```bash
#!/bin/bash
# 脚本描述

set -e

VARIABLE_NAME="value"

function_name() {
    local param=$1
    # 函数逻辑
}
```

### 文档

- 使用 Markdown 格式
- 中文文档使用中文标点
- 代码块指定语言
- 保持文档更新

## 开发流程

1. **讨论**：对于大的改动，先创建 Issue 讨论
2. **开发**：在特性分支上开发
3. **测试**：确保所有测试通过
4. **文档**：更新相关文档
5. **提交**：创建 Pull Request
6. **审查**：等待维护者审查
7. **合并**：审查通过后合并

## 测试

在提交 PR 前，请确保：

- [ ] 代码可以成功构建
- [ ] 镜像可以正常启动
- [ ] 所有服务正常运行
- [ ] 文档已更新

测试命令：
```bash
sudo make all
make test
```

## 需要帮助？

- 查看 [FAQ.md](FAQ.md)
- 查看 [BUILD.md](BUILD.md)
- 在 Issues 中提问
- 发送邮件（如果有）

## 行为准则

- 尊重他人
- 保持友善和专业
- 接受建设性批评
- 关注对项目最有利的事情

## 许可证

通过贡献代码，你同意你的贡献将在 MIT 许可证下发布。

---

再次感谢你的贡献！🎉
