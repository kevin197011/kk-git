# kk-git

[![Gem Version](https://img.shields.io/gem/v/kk-git.svg)](https://rubygems.org/gems/kk-git)
[![Gem Downloads](https://img.shields.io/gem/dt/kk-git.svg)](https://rubygems.org/gems/kk-git)

Git 辅助工具：从变更自动生成 [Conventional Commits](https://www.conventionalcommits.org/) 消息，并支持一键 add/commit/pull/push。

## Install (RubyGems)

### Option 1: Global install (recommended)

```bash
gem install kk-git
```

After installation you can use the `kk-git` command directly.

### Check installed version

```bash
kk-git --version
```

### Option 2: Add to your project

```ruby
# Gemfile
gem 'kk-git'
```

## CLI

```bash
kk-git commit-message --worktree   # 从工作区生成 commit message
kk-git commit-message --staged     # 从暂存区生成
kk-git commit-message --all        # 暂存区 + 工作区
kk-git status                      # 查看分支同步状态
kk-git status --format json        # JSON 输出
kk-git sync                        # 仅 pull + push（不 commit）
kk-git push                        # 完整 auto add/commit/pull/push
```

Run from this repo (without installing the gem):

```bash
ruby -Ilib exe/kk-git commit-message --worktree
ruby -Ilib exe/kk-git status
ruby -Ilib exe/kk-git push
```

Override inference (type/scope/subject):

```bash
kk-git commit-message --worktree --type chore --scope tools --subject "Update tools"
```

JSON output (for scripting):

```bash
kk-git commit-message --worktree --format json
```

## Rake

Usage in another repo (recommended):

```ruby
# Rakefile
require 'bundler/setup'
require 'kk/git/rake_tasks'

task default: %w[push]

task :push do
  Rake::Task['git:auto_commit_push'].invoke
end
```

```bash
rake git:status                  # 分支同步状态
rake git:sync                    # 仅 pull + push
rake git:commit_message          # staged (default)
rake git:commit_message_worktree # worktree (includes untracked)
rake git:auto_commit             # staged + worktree (generate/print commit message)
rake git:auto_commit_push        # auto add/commit/pull/push
```

## `git:auto_commit_push` / `kk-git push` behavior

Execution order:

1) If working tree is clean but ahead/behind remote: `git pull` + `git push` and stop  
2) If working tree is clean and in sync: print `No changes to commit or push` and stop  
3) `git add` (default: `.`, configurable via `KK_GIT_ADD_PATHS`)  
4) generate commit message (Conventional Commits)  
5) `git commit` (or `git commit --amend` when `KK_GIT_AMEND=1`)  
6) `git pull <remote> <branch> --ff-only` (default)  
7) `git push <remote> <branch>` (auto `-u` on first push when upstream not set)

## Environment variables

### Remote / sync

| Variable | Default | Description |
|----------|---------|-------------|
| `KK_GIT_REMOTE` | `origin` | Remote name |
| `KK_GIT_BRANCH` | current branch | Branch name |
| `KK_GIT_PULL_ARGS` | `--ff-only` | Extra args appended to `git pull <remote> <branch>` |
| `KK_GIT_ADD_PATHS` | `.` | Paths for `git add` (space-separated) |
| `KK_GIT_DRY_RUN` | — | Set to `1` to print commands without executing |
| `KK_GIT_SKIP_PULL` | — | Set to `1` to skip pull |
| `KK_GIT_SKIP_PUSH` | — | Set to `1` to skip push |
| `KK_GIT_AMEND` | — | Set to `1` to amend last commit |

### Commit message overrides

| Variable | Description |
|----------|-------------|
| `KK_GIT_TYPE` | Override type (`feat`, `fix`, `docs`, …) |
| `KK_GIT_SCOPE` | Override scope |
| `KK_GIT_SUBJECT` | Override subject |

Rake tasks store generated message in `ENV['KK_GIT_COMMIT_MESSAGE']`.

## Programmatic API

```ruby
require 'kk/git'

# 生成 commit message
KKGit::CommitMessage.generate(mode: :all)

# 仓库状态
KKGit::GitOps.status        # => Status struct (ahead/behind/clean/…)
KKGit::GitOps.status_hash   # => Hash (JSON-friendly)

# 自动 commit + sync
KKGit::GitOps.auto_commit_push!
KKGit::GitOps.sync_with_remote!('origin', 'main')
```

## Safety notes

- **Detached HEAD**: push 会被拒绝并给出明确错误
- **非 git 目录**: 操作前会检测并报错
- **首次 push**: 无 upstream 时自动使用 `git push -u`
- **pull 冲突**: `--ff-only` 失败时会抛出错误，需手动解决后重试
- **敏感文件**: 可用 `KK_GIT_ADD_PATHS="src spec"` 避免 `git add .` 误加文件

## Test

```bash
ruby scripts/test.rb
```

## Release to RubyGems (GitHub Actions)

Workflow: `.github/workflows/release-gem.yml`

### 1) Configure Secret

In GitHub repo `Settings -> Secrets and variables -> Actions`, add:

- `RUBYGEMS_API_KEY`: RubyGems API key (used as `GEM_HOST_API_KEY` for `gem push`)

### 2) Create a tag to release

```bash
# Example: release 0.2.0
git tag v0.2.0
git push origin v0.2.0
```

You can also trigger it manually via `workflow_dispatch` in GitHub Actions.
