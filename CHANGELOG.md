# Changelog

All notable changes to this project are documented in this file.

## 0.2.2 (unreleased)

### Changed

- Unify maintainer `rake push` with `KKGit::GitOps.auto_commit_push!`
- Extract `GitRunner` and `Release` modules; remove duplicate git helpers
- Default code-change commit type is `chore` (override with `KK_GIT_DEFAULT_TYPE`)
- Refuse committing sensitive paths (`.env`, credentials, keys) unless `KK_GIT_ALLOW_SENSITIVE=1`
- Remove empty-message fallback with timestamp; fail instead when message cannot be generated
- Add `--repo` to `kk-git status`, `sync`, and `push`
- Add `KK_GIT_CONFIRM` / `KK_GIT_YES` for commit confirmation
- Expand `scripts/test.rb` coverage; add GitHub Actions CI workflow
- Remove unused docker deploy scripts and dead code (`pick_scope`)

## 0.2.1

- GitOps module with sync/push flow
- CLI: `commit-message`, `status`, `sync`, `push`
- Rake tasks under `git:` namespace

## 0.2.0

- Initial RubyGems release with Conventional Commits inference
