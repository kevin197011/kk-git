# kk-git

[![Gem Version](https://img.shields.io/gem/v/kk-git.svg)](https://rubygems.org/gems/kk-git)
[![Gem Downloads](https://img.shields.io/gem/dt/kk-git.svg)](https://rubygems.org/gems/kk-git)

## 安装（RubyGems）

### 方式 1：全局安装（推荐）

```bash
gem install kk-git
```

安装后可直接使用命令 `kk-git`。

### 查看已安装版本

```bash
kk-git --version
```

### 方式 2：加入项目依赖

```ruby
# Gemfile
gem 'kk-git'
```

## 自动生成 commit message（Conventional Commits）

### CLI 使用

已安装 gem 的情况下：

```bash
kk-git commit-message --worktree
kk-git commit-message --staged
kk-git commit-message --all
```

在本仓库内直接运行（不需要先安装 gem）：

```bash
ruby -Ilib exe/kk-git commit-message --worktree
ruby -Ilib exe/kk-git commit-message --staged
ruby -Ilib exe/kk-git commit-message --all
```

覆盖自动推断（手动指定 type/scope/subject）：

```bash
kk-git commit-message --worktree --type chore --scope tools --subject "维护工具"
```

输出 JSON（方便脚本消费）：

```bash
kk-git commit-message --worktree --format json
```

### Rake 调用

在其它仓库里使用（推荐）：

```ruby
# Rakefile
require 'bundler/setup'
require 'kk/git/rake_tasks'

# 然后就可以直接调用：
# Rake::Task['git:auto_commit'].invoke
```

```bash
rake git:commit_message          # 基于暂存区（默认）
rake git:commit_message_worktree # 基于工作区（含 untracked）
rake git:auto_commit             # 合并暂存区+工作区（仅生成/输出 commit message）
rake git:auto_commit_push        # 自动 add/commit/pull/push
```

#### `git:auto_commit_push` 行为与配置

执行顺序固定为：

1) `git add .`  
2) 生成 commit message（等价于调用 `git:auto_commit`）  
3) `git commit`  
4) `git pull`（默认 `--ff-only`，适合非交互环境）  
5) `git push`

可选环境变量：

- `KK_GIT_REMOTE`: 远端名，默认 `origin`
- `KK_GIT_BRANCH`: 分支名，默认当前分支
- `KK_GIT_PULL_ARGS`: `git pull` 的参数字符串，默认 `--ff-only`（例如可设为 `--rebase`）

### 环境变量覆盖

- `KK_GIT_TYPE`: 覆盖 type
- `KK_GIT_SCOPE`: 覆盖 scope
- `KK_GIT_SUBJECT`: 覆盖 subject

## 发布到 RubyGems（GitHub Actions）

已提供工作流：`.github/workflows/release-gem.yml`

### 1) 配置 Secret

在 GitHub 仓库 `Settings -> Secrets and variables -> Actions` 新增：

- `RUBYGEMS_API_KEY`: RubyGems 的 API key（工作流会作为 `GEM_HOST_API_KEY` 注入到 `gem push`）

### 2) 打 tag 触发发布

```bash
# 例：发布 0.1.0
git tag v0.1.0
git push origin v0.1.0
```

也可以在 GitHub Actions 页面手动 `workflow_dispatch` 触发。

