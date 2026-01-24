# frozen_string_literal: true

require 'rake'
require 'kk/git'
require 'open3'
require 'tempfile'

module KKGit
  # Rake 集成：在任意项目的 Rakefile 中 `require 'kk/git/rake_tasks'` 即可注册任务。
  #
  # 说明：
  # - 这些任务**不会 exit/abort**，以便在其它 task 中被 invoke。
  # - 会把生成结果写入 `ENV['KK_GIT_COMMIT_MESSAGE']`，方便上层 task 复用。
  module RakeTasks
    def self.run_cmd(*cmd)
      stdout, stderr, status = Open3.capture3(*cmd)
      [stdout.to_s, stderr.to_s, status.success?]
    end

    def self.ensure_ok!(ok, title, stdout: nil, stderr: nil)
      return if ok

      msg = +"#{title} 失败"
      msg << "\n#{stderr}" unless stderr.to_s.strip.empty?
      msg << "\n#{stdout}" unless stdout.to_s.strip.empty?
      raise msg
    end

    def self.current_branch
      out, err, ok = run_cmd('git', 'rev-parse', '--abbrev-ref', 'HEAD')
      ensure_ok!(ok, '获取当前分支', stdout: out, stderr: err)
      out.strip
    end

    def self.working_tree_clean?
      out, err, ok = run_cmd('git', 'status', '--porcelain')
      ensure_ok!(ok, '检查 git 状态', stdout: out, stderr: err)
      out.strip.empty?
    end

    def self.install!
      extend Rake::DSL

      namespace :git do
        desc '根据暂存区变更生成 commit message（Conventional Commits）'
        task :commit_message do
          msg = KKGit::CommitMessage.generate(mode: :staged)
          ENV['KK_GIT_COMMIT_MESSAGE'] = msg.to_s
          puts msg if msg
        end

        desc '根据工作区变更生成 commit message（含 untracked）'
        task :commit_message_worktree do
          msg = KKGit::CommitMessage.generate(mode: :worktree)
          ENV['KK_GIT_COMMIT_MESSAGE'] = msg.to_s
          puts msg if msg
        end

        desc '合并暂存区+工作区变更生成 commit message'
        task :auto_commit do
          msg = KKGit::CommitMessage.generate(mode: :all)
          ENV['KK_GIT_COMMIT_MESSAGE'] = msg.to_s
          puts msg if msg
        end

        desc '自动 add/commit/pull/push（基于 git:auto_commit）'
        task :auto_commit_push do
          if working_tree_clean?
            puts '没有变更需要提交'
            next
          end

          remote = ENV.fetch('KK_GIT_REMOTE', 'origin')
          branch = ENV.fetch('KK_GIT_BRANCH', current_branch)

          # 1) add
          out, err, ok = run_cmd('git', 'add', '.')
          ensure_ok!(ok, 'git add', stdout: out, stderr: err)

          # 2) 生成 commit message（允许重复 invoke）
          Rake::Task['git:auto_commit'].reenable
          Rake::Task['git:auto_commit'].invoke
          commit_message = ENV['KK_GIT_COMMIT_MESSAGE'].to_s.strip
          commit_message = "chore(repo): 更新项目文件\n\n#{Time.now}" if commit_message.empty?

          # 3) commit（用临时文件避免转义问题）
          Tempfile.create('commit_message') do |f|
            f.write(commit_message)
            f.flush
            out, err, ok = run_cmd('git', 'commit', '-F', f.path)
            # 没有 staged 变更时 git commit 会失败；这里给出更友好的提示
            unless ok
              if err.include?('nothing to commit') || out.include?('nothing to commit')
                puts '没有暂存变更需要提交'
                next
              end
            end
            ensure_ok!(ok, 'git commit', stdout: out, stderr: err)
          end

          # 4) pull（默认使用 --ff-only，避免非交互环境进入合并流程）
          pull_args = ENV.fetch('KK_GIT_PULL_ARGS', '--ff-only').split
          out, err, ok = run_cmd('git', 'pull', *pull_args)
          ensure_ok!(ok, 'git pull', stdout: out, stderr: err)

          # 5) push
          out, err, ok = run_cmd('git', 'push', remote, branch)
          ensure_ok!(ok, 'git push', stdout: out, stderr: err)

          puts "✅ 已推送: #{remote} #{branch}"
        end
      end
    end
  end
end

KKGit::RakeTasks.install!

