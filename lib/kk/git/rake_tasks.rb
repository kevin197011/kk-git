# frozen_string_literal: true

require 'rake'
require_relative '../git'
require 'open3'
require 'tempfile'

module KKGit
  # Rake integration: `require 'kk/git/rake_tasks'` to register tasks.
  #
  # Notes:
  # - These tasks do NOT exit/abort so they can be invoked by other tasks.
  # - The generated message is stored in `ENV['KK_GIT_COMMIT_MESSAGE']`.
  module RakeTasks
    def self.run_cmd(*cmd)
      stdout, stderr, status = Open3.capture3(*cmd)
      [stdout.to_s, stderr.to_s, status.success?]
    end

    def self.ensure_ok!(ok, title, stdout: nil, stderr: nil)
      return if ok

      msg = +"#{title} failed"
      msg << "\n#{stderr}" unless stderr.to_s.strip.empty?
      msg << "\n#{stdout}" unless stdout.to_s.strip.empty?
      raise msg
    end

    def self.current_branch
      out, err, ok = run_cmd('git', 'rev-parse', '--abbrev-ref', 'HEAD')
      ensure_ok!(ok, 'Get current branch', stdout: out, stderr: err)
      out.strip
    end

    def self.working_tree_clean?
      out, err, ok = run_cmd('git', 'status', '--porcelain')
      ensure_ok!(ok, 'Check git status', stdout: out, stderr: err)
      out.strip.empty?
    end

    def self.install!
      extend Rake::DSL

      namespace :git do
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
          if working_tree_clean?
            puts 'No changes to commit'
            next
          end

          remote = ENV.fetch('KK_GIT_REMOTE', 'origin')
          branch = ENV.fetch('KK_GIT_BRANCH', current_branch)

          # 1) add
          out, err, ok = run_cmd('git', 'add', '.')
          ensure_ok!(ok, 'git add', stdout: out, stderr: err)

          # 2) generate commit message (allow re-invoke)
          Rake::Task['git:auto_commit'].reenable
          Rake::Task['git:auto_commit'].invoke
          commit_message = ENV['KK_GIT_COMMIT_MESSAGE'].to_s.strip
          commit_message = "chore(repo): update project files\n\n#{Time.now}" if commit_message.empty?

          # 3) commit (use a tempfile to avoid escaping issues)
          Tempfile.create('commit_message') do |f|
            f.write(commit_message)
            f.flush
            out, err, ok = run_cmd('git', 'commit', '-F', f.path)
            # If there are no staged changes, git commit fails; show a friendlier message.
            unless ok
              if err.include?('nothing to commit') || out.include?('nothing to commit')
                puts 'No staged changes to commit'
                next
              end
            end
            ensure_ok!(ok, 'git commit', stdout: out, stderr: err)
          end

          # 4) pull (default: --ff-only to avoid interactive merges)
          pull_args = ENV.fetch('KK_GIT_PULL_ARGS', '--ff-only').split
          out, err, ok = run_cmd('git', 'pull', *pull_args)
          ensure_ok!(ok, 'git pull', stdout: out, stderr: err)

          # 5) push
          out, err, ok = run_cmd('git', 'push', remote, branch)
          ensure_ok!(ok, 'git push', stdout: out, stderr: err)

          puts "Pushed: #{remote} #{branch}"
        end
      end
    end
  end
end

KKGit::RakeTasks.install!

