## 目标

生成一个 Ruby gem 工具：根据当前 Git repo 的修改内容自动生成 Conventional Commits 格式的 commit message，方便在 `Rakefile` 中调用。

## 实现

- **Ruby API**: `KKGit::CommitMessage.generate(...)`
- **CLI**: `exe/kk-git commit-message ...`
- **Rake tasks**:
  - `rake git:commit_message`（暂存区）
  - `rake git:commit_message_worktree`（工作区，含 untracked）
  - `rake git:commit_message_all`（合并）

## 示例

```bash
# 工作区（含 untracked）
ruby -Ilib exe/kk-git commit-message --worktree

# 暂存区（先 git add）
ruby -Ilib exe/kk-git commit-message --staged

# Rake
rake git:commit_message_worktree
```

