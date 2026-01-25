## Goal

Build a Ruby gem that generates Conventional Commits messages from the current git repo changes, designed to be used from `Rakefile`.

## Implementation

- **Ruby API**: `KKGit::CommitMessage.generate(...)`
- **CLI**: `kk-git commit-message ...`
- **Rake tasks**:
  - `rake git:commit_message` (staged)
  - `rake git:commit_message_worktree` (worktree, includes untracked)
  - `rake git:auto_commit` (staged + worktree, generate/print message)
  - `rake git:auto_commit_push` (add/commit/pull/push)

## Examples

```bash
# Worktree (includes untracked)
kk-git commit-message --worktree

# Staged (after git add)
kk-git commit-message --staged

# Rake
rake git:auto_commit
```

