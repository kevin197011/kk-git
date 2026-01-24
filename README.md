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

