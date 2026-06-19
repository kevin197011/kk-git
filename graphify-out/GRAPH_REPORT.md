# Graph Report - kk-git  (2026-06-20)

## Corpus Check
- 14 files · ~6,856 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 186 nodes · 291 edges · 16 communities (13 shown, 3 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 19 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `1e2c26df`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]

## God Nodes (most connected - your core abstractions)
1. `CommitMessage` - 28 edges
2. `status()` - 19 edges
3. `OpenSpec Instructions` - 15 edges
4. `run_cmd()` - 13 edges
5. `auto_commit_push!()` - 12 edges
6. `TestRunner` - 11 edges
7. `kk-git` - 10 edges
8. `install!()` - 8 edges
9. `push_remote!()` - 8 edges
10. `ensure_ok!()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `install!()` --calls--> `status()`  [INFERRED]
  lib/kk/git/rake_tasks.rb → lib/kk/git/git_ops.rb
- `install!()` --calls--> `branch()`  [INFERRED]
  lib/kk/git/rake_tasks.rb → lib/kk/git/git_ops.rb
- `install!()` --calls--> `remote()`  [INFERRED]
  lib/kk/git/rake_tasks.rb → lib/kk/git/git_ops.rb
- `install!()` --calls--> `needs_sync?()`  [INFERRED]
  lib/kk/git/rake_tasks.rb → lib/kk/git/git_ops.rb
- `install!()` --calls--> `sync_with_remote!()`  [INFERRED]
  lib/kk/git/rake_tasks.rb → lib/kk/git/git_ops.rb

## Communities (16 total, 3 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (35): Before Any Task, Best Practices, Capability Naming, Change Conflicts, Change ID Naming, Clear References, CLI Commands, code:bash (# Essential commands) (+27 more)

### Community 1 - "Community 1"
Cohesion: 0.15
Nodes (30): add_all!(), ahead_count(), amend?(), auto_commit_push!(), behind_count(), branch(), commit_with_message!(), current_branch() (+22 more)

### Community 3 - "Community 3"
Cohesion: 0.09
Nodes (22): 1) Configure Secret, 2) Create a tag to release, CLI, code:ruby (require 'kk/git'), code:bash (ruby scripts/test.rb), code:bash (# Example: release 0.2.0), code:bash (kk-git commit-message --worktree   # 从工作区生成 commit message), code:bash (ruby -Ilib exe/kk-git commit-message --worktree) (+14 more)

### Community 4 - "Community 4"
Cohesion: 0.17
Nodes (11): Architecture Patterns, Code Style, Domain Context, External Dependencies, Git Workflow, Important Constraints, Project Context, Project Conventions (+3 more)

### Community 6 - "Community 6"
Cohesion: 0.25
Nodes (8): code:block3 (New request?), code:markdown (# Change: [Brief description of change]), code:markdown (## ADDED Requirements), code:markdown (## 1. Implementation), code:markdown (## Context), Creating Change Proposals, Decision Tree, Proposal Structure

### Community 7 - "Community 7"
Cohesion: 0.25
Nodes (8): code:markdown (## RENAMED Requirements), code:markdown (#### Scenario: User login success), code:markdown (- **Scenario: User login**  ❌), Critical: Scenario Formatting, Delta Operations, Requirement Wording, Spec File Format, When to use ADDED vs MODIFIED

### Community 8 - "Community 8"
Cohesion: 0.29
Nodes (7): Check installed version, code:bash (gem install kk-git), code:bash (kk-git --version), code:ruby (# Gemfile), Install (RubyGems), Option 1: Global install (recommended), Option 2: Add to your project

### Community 9 - "Community 9"
Cohesion: 0.40
Nodes (4): code:bash (# Worktree (includes untracked)), Examples, Goal, Implementation

### Community 10 - "Community 10"
Cohesion: 0.40
Nodes (5): CLI Essentials, code:bash (openspec list              # What's in progress?), File Purposes, Quick Reference, Stage Indicators

## Knowledge Gaps
- **66 isolated node(s):** `Error`, `code:bash (gem install kk-git)`, `code:bash (kk-git --version)`, `code:ruby (# Gemfile)`, `code:bash (kk-git commit-message --worktree   # 从工作区生成 commit message)` (+61 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `OpenSpec Instructions` connect `Community 0` to `Community 10`, `Community 6`, `Community 7`?**
  _High betweenness centrality (0.084) - this node is a cross-community bridge._
- **Why does `status()` connect `Community 1` to `Community 2`, `Community 5`?**
  _High betweenness centrality (0.062) - this node is a cross-community bridge._
- **Are the 8 inferred relationships involving `status()` (e.g. with `.test_git_ops_in_temp_repo()` and `.generate_hash()`) actually correct?**
  _`status()` has 8 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `auto_commit_push!()` (e.g. with `.test_git_ops_in_temp_repo()` and `install!()`) actually correct?**
  _`auto_commit_push!()` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Error`, `code:bash (gem install kk-git)`, `code:bash (kk-git --version)` to the rest of the system?**
  _66 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.05555555555555555 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.1495798319327731 - nodes in this community are weakly interconnected._