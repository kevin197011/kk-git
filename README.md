# kk-git
kk-git

## 自动生成 commit message（Conventional Commits）

### CLI 使用

在本仓库内直接运行（不需要先安装 gem）：

```bash
ruby -Ilib exe/kk-git commit-message --worktree
ruby -Ilib exe/kk-git commit-message --staged
ruby -Ilib exe/kk-git commit-message --all
```

覆盖自动推断（手动指定 type/scope/subject）：

```bash
ruby -Ilib exe/kk-git commit-message --worktree --type chore --scope tools --subject "维护工具"
```

输出 JSON（方便脚本消费）：

```bash
ruby -Ilib exe/kk-git commit-message --worktree --format json
```

### Rake 调用

```bash
rake git:commit_message          # 基于暂存区（默认）
rake git:commit_message_worktree # 基于工作区（含 untracked）
rake git:commit_message_all      # 合并暂存区+工作区
```

### 环境变量覆盖

- `KK_GIT_TYPE`: 覆盖 type
- `KK_GIT_SCOPE`: 覆盖 scope
- `KK_GIT_SUBJECT`: 覆盖 subject

## 发布到 RubyGems（GitHub Actions）

已提供工作流：`.github/workflows/release-gem.yml`

### 1) 配置 Secret

在 GitHub 仓库 `Settings -> Secrets and variables -> Actions` 新增：

- `RUBYGEMS_API_KEY`: RubyGems 的 API key（建议启用 MFA 的 key）

### 2) 打 tag 触发发布

```bash
# 例：发布 0.1.0
git tag v0.1.0
git push origin v0.1.0
```

也可以在 GitHub Actions 页面手动 `workflow_dispatch` 触发。

