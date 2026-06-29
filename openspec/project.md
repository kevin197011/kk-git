# Project Context

## Purpose

`kk-git` is a Ruby gem and CLI that generates [Conventional Commits](https://www.conventionalcommits.org/) messages from git changes and automates add/commit/pull/push workflows for local development and Rake-based tooling.

## Tech Stack

- Ruby >= 3.1 (stdlib only in the gem runtime)
- Git CLI (required on PATH)
- RubyGems for distribution
- GitHub Actions for CI and gem release

## Project Conventions

### Code Style

- `# frozen_string_literal: true` on Ruby files
- Module namespace: `KKGit`
- Prefer small modules over heavy abstractions
- RuboCop enabled via `.rubocop.yml`

### Architecture Patterns

- `CommitMessage` — pure inference from git diffs (no network)
- `GitOps` — mutating git operations shared by CLI and Rake
- `GitRunner` — shared subprocess wrapper
- `Release` — maintainer semver/tag helpers (used by root `Rakefile`)
- Entry points: `exe/kk-git`, `lib/kk/git/rake_tasks.rb`, `require 'kk/git'`

### Testing Strategy

- Run `ruby scripts/test.rb` (no test framework; temp git repos)
- CI runs the same script on push/PR
- Add focused assertions when changing inference or GitOps behavior

### Git Workflow

- Conventional Commits for user-facing changes
- Maintainer flow: `rake push` (optional auto version bump + tag via `KK_GIT_AUTO_TAG`)
- Gem release: push `v*` tag → GitHub Actions publishes to RubyGems

## Domain Context

- **Modes**: `:staged`, `:worktree`, `:all` for change collection
- **Safety**: sensitive path guard, detached HEAD check, default `pull --ff-only`
- **Overrides**: `KK_GIT_*` environment variables (see README)

## Important Constraints

- Must work without Bundler at runtime (gem has no runtime dependencies)
- Must not silently commit sensitive files by default
- Breaking API changes require a major version bump and CHANGELOG entry

## External Dependencies

- Git
- RubyGems (publish)
- GitHub Actions (`RUBYGEMS_API_KEY` secret for release workflow)
