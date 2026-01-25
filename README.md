# kk-git

[![Gem Version](https://img.shields.io/gem/v/kk-git.svg)](https://rubygems.org/gems/kk-git)
[![Gem Downloads](https://img.shields.io/gem/dt/kk-git.svg)](https://rubygems.org/gems/kk-git)

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

## Generate commit messages (Conventional Commits)

### CLI

When installed:

```bash
kk-git commit-message --worktree
kk-git commit-message --staged
kk-git commit-message --all
```

Run from this repo (without installing the gem):

```bash
ruby -Ilib exe/kk-git commit-message --worktree
ruby -Ilib exe/kk-git commit-message --staged
ruby -Ilib exe/kk-git commit-message --all
```

Override inference (type/scope/subject):

```bash
kk-git commit-message --worktree --type chore --scope tools --subject "Update tools"
```

JSON output (for scripting):

```bash
kk-git commit-message --worktree --format json
```

### Rake

Usage in another repo (recommended):

```ruby
# Rakefile
require 'bundler/setup'
require 'kk/git/rake_tasks'

# Then you can invoke tasks directly:
# Rake::Task['git:auto_commit'].invoke
```

Minimal example (bind default task to push):

```ruby
require 'bundler/setup'
require 'kk/git/rake_tasks'

task default: %w[push]

task :push do
  Rake::Task['git:auto_commit_push'].invoke
end
```

```bash
rake git:commit_message          # staged (default)
rake git:commit_message_worktree # worktree (includes untracked)
rake git:auto_commit             # staged + worktree (generate/print commit message)
rake git:auto_commit_push        # auto add/commit/pull/push
```

#### `git:auto_commit_push` behavior & config

Execution order:

1) `git add .`  
2) generate commit message (same as `git:auto_commit`)  
3) `git commit`  
4) `git pull` (default: `--ff-only`, good for non-interactive environments)  
5) `git push`

Optional environment variables:

- `KK_GIT_REMOTE`: remote name (default: `origin`)
- `KK_GIT_BRANCH`: branch name (default: current branch)
- `KK_GIT_PULL_ARGS`: args for `git pull` (default: `--ff-only`, e.g. `--rebase`)

### Environment overrides

- `KK_GIT_TYPE`: override type
- `KK_GIT_SCOPE`: override scope
- `KK_GIT_SUBJECT`: override subject

## Release to RubyGems (GitHub Actions)

Workflow: `.github/workflows/release-gem.yml`

### 1) Configure Secret

In GitHub repo `Settings -> Secrets and variables -> Actions`, add:

- `RUBYGEMS_API_KEY`: RubyGems API key (used as `GEM_HOST_API_KEY` for `gem push`)

### 2) Create a tag to release

```bash
# Example: release 0.1.0
git tag v0.1.0
git push origin v0.1.0
```

You can also trigger it manually via `workflow_dispatch` in GitHub Actions.

