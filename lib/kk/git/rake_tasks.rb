# frozen_string_literal: true

require 'rake'
require 'kk/git'

module KKGit
  # Rake 集成：在任意项目的 Rakefile 中 `require 'kk/git/rake_tasks'` 即可注册任务。
  #
  # 说明：
  # - 这些任务**不会 exit/abort**，以便在其它 task 中被 invoke。
  # - 会把生成结果写入 `ENV['KK_GIT_COMMIT_MESSAGE']`，方便上层 task 复用。
  module RakeTasks
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
        task :commit_message_all do
          msg = KKGit::CommitMessage.generate(mode: :all)
          ENV['KK_GIT_COMMIT_MESSAGE'] = msg.to_s
          puts msg if msg
        end
      end
    end
  end
end

KKGit::RakeTasks.install!

