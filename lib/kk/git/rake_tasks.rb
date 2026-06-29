# frozen_string_literal: true

require 'rake'
require_relative '../git'

module KKGit
  # Rake integration: `require 'kk/git/rake_tasks'` to register tasks.
  #
  # Notes:
  # - These tasks do NOT exit/abort so they can be invoked by other tasks.
  # - The generated message is stored in `ENV['KK_GIT_COMMIT_MESSAGE']`.
  module RakeTasks
    def self.install!
      extend Rake::DSL

      namespace :git do
        desc 'Show branch sync status (ahead/behind/clean)'
        task :status do
          s = KKGit::GitOps.status
          puts "Branch: #{s.branch} (#{s.remote})"
          puts "Working tree: #{s.clean ? 'clean' : 'dirty'}"
          puts "Ahead: #{s.ahead}, Behind: #{s.behind}"
          puts "Upstream: #{s.upstream_configured ? 'configured' : 'not set'}"
          puts 'Detached HEAD: yes' if s.detached
        end

        desc 'Pull and push without committing (sync unpushed or behind commits)'
        task :sync do
          remote = KKGit::GitOps.remote
          branch = KKGit::GitOps.branch
          s = KKGit::GitOps.status(remote: remote, branch: branch)

          if s.needs_sync?
            KKGit::GitOps.sync_with_remote!(remote, branch)
          else
            puts 'Already in sync with remote'
          end
        end

        desc 'Generate commit message from staged changes (Conventional Commits)'
        task :commit_message do
          msg = KKGit::CommitMessage.generate(mode: :staged)
          ENV['KK_GIT_COMMIT_MESSAGE'] = msg.to_s
          puts msg if msg
        end

        desc 'Generate commit message from working-tree changes (includes untracked)'
        task :commit_message_worktree do
          msg = KKGit::CommitMessage.generate(mode: :worktree)
          ENV['KK_GIT_COMMIT_MESSAGE'] = msg.to_s
          puts msg if msg
        end

        desc 'Generate commit message from staged + working-tree changes'
        task :auto_commit do
          msg = KKGit::CommitMessage.generate(mode: :all)
          ENV['KK_GIT_COMMIT_MESSAGE'] = msg.to_s
          puts msg if msg
        end

        desc 'Auto add/commit/pull/push (uses git:auto_commit)'
        task :auto_commit_push do
          generator = lambda do
            Rake::Task['git:auto_commit'].reenable
            Rake::Task['git:auto_commit'].invoke
            ENV['KK_GIT_COMMIT_MESSAGE'].to_s
          end

          KKGit::GitOps.auto_commit_push!(commit_message_generator: generator)
        rescue KKGit::GitOps::Error => e
          warn e.message
          exit 1
        end
      end
    end
  end
end

KKGit::RakeTasks.install!
