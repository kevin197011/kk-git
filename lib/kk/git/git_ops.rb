# frozen_string_literal: true

require 'open3'
require 'tempfile'

module KKGit
  # Git 仓库操作：供 Rake task 与 CLI 复用。
  module GitOps
    class Error < StandardError; end

    # 仓库同步状态快照
    Status = Struct.new(
      :branch, :remote, :clean, :ahead, :behind,
      :upstream_configured, :detached,
      keyword_init: true
    ) do
      # 是否需要与远端同步（有未推送 commit 或落后远端）
      def needs_sync?
        ahead.positive? || behind.positive?
      end

      def unpushed?
        ahead.positive?
      end

      def behind_remote?
        behind.positive?
      end
    end

    class << self
      # @return [Boolean] KK_GIT_DRY_RUN=1 时只打印命令不执行
      def dry_run?
        ENV['KK_GIT_DRY_RUN'] == '1'
      end

      def skip_pull?
        ENV['KK_GIT_SKIP_PULL'] == '1'
      end

      def skip_push?
        ENV['KK_GIT_SKIP_PUSH'] == '1'
      end

      def amend?
        ENV['KK_GIT_AMEND'] == '1'
      end

      def remote
        ENV.fetch('KK_GIT_REMOTE', 'origin')
      end

      # @param explicit [String, nil] KK_GIT_BRANCH 或显式传入
      def branch(explicit: ENV['KK_GIT_BRANCH'])
        explicit.to_s.strip.empty? ? current_branch : explicit.to_s.strip
      end

      # git add 路径，默认 `.`；可用 KK_GIT_ADD_PATHS 指定多个路径（空格分隔）
      def add_paths
        ENV.fetch('KK_GIT_ADD_PATHS', '.').split(/\s+/).reject(&:empty?)
      end

      # 会修改仓库状态的 git 子命令；dry-run 时跳过这些命令
      MUTATING_GIT_COMMANDS = %w[add commit push pull merge rebase checkout reset cherry-pick revert].freeze

      def run_cmd(*cmd, chdir: nil)
        if dry_run? && mutating_git_command?(cmd)
          label = chdir ? "(cd #{chdir} && #{cmd.join(' ')})" : cmd.join(' ')
          puts "[dry-run] #{label}"
          return ['', '', true]
        end

        stdout, stderr, status =
          if chdir
            Open3.capture3(*cmd, chdir: chdir)
          else
            Open3.capture3(*cmd)
          end
        [stdout.to_s, stderr.to_s, status.success?]
      end

      def mutating_git_command?(cmd)
        cmd[0] == 'git' && MUTATING_GIT_COMMANDS.include?(cmd[1])
      end

      def ensure_ok!(ok, title, stdout: nil, stderr: nil)
        return if ok

        msg = +"#{title} failed"
        msg << "\n#{stderr}" unless stderr.to_s.strip.empty?
        msg << "\n#{stdout}" unless stdout.to_s.strip.empty?
        raise Error, msg
      end

      def in_git_repo?
        _, _, ok = run_cmd('git', 'rev-parse', '--git-dir')
        ok
      end

      def ensure_in_repo!
        raise Error, 'Not a git repository' unless in_git_repo?
      end

      def current_branch
        out, err, ok = run_cmd('git', 'rev-parse', '--abbrev-ref', 'HEAD')
        ensure_ok!(ok, 'Get current branch', stdout: out, stderr: err)
        out.strip
      end

      def detached_head?
        current_branch == 'HEAD'
      end

      def ensure_not_detached!
        raise Error, 'Cannot push from detached HEAD' if detached_head?
      end

      def working_tree_clean?
        out, err, ok = run_cmd('git', 'status', '--porcelain')
        ensure_ok!(ok, 'Check git status', stdout: out, stderr: err)
        out.strip.empty?
      end

      def upstream_configured?
        _, _, ok = run_cmd('git', 'rev-parse', '--abbrev-ref', '@{u}')
        ok
      end

      # 相对 upstream / remote/branch 领先的 commit 数
      def ahead_count(remote, branch)
        out, _err, ok = run_cmd('git', 'rev-list', '--count', '@{u}..HEAD')
        return out.strip.to_i if ok

        out, _err, ok = run_cmd('git', 'rev-list', '--count', "#{remote}/#{branch}..HEAD")
        return out.strip.to_i if ok

        0
      end

      # 相对 upstream / remote/branch 落后的 commit 数
      def behind_count(remote, branch)
        out, _err, ok = run_cmd('git', 'rev-list', '--count', 'HEAD..@{u}')
        return out.strip.to_i if ok

        out, _err, ok = run_cmd('git', 'rev-list', '--count', "HEAD..#{remote}/#{branch}")
        return out.strip.to_i if ok

        0
      end

      def unpushed_commits?(remote, branch)
        ahead_count(remote, branch).positive?
      end

      # @return [Status]
      def status(remote: nil, branch: nil)
        ensure_in_repo!
        remote ||= self.remote
        branch ||= self.branch

        Status.new(
          branch: branch,
          remote: remote,
          clean: working_tree_clean?,
          ahead: ahead_count(remote, branch),
          behind: behind_count(remote, branch),
          upstream_configured: upstream_configured?,
          detached: detached_head?
        )
      end

      def status_hash(remote: nil, branch: nil)
        s = status(remote: remote, branch: branch)
        {
          branch: s.branch,
          remote: s.remote,
          clean: s.clean,
          ahead: s.ahead,
          behind: s.behind,
          upstream_configured: s.upstream_configured,
          detached: s.detached,
          needs_sync: s.needs_sync?
        }
      end

      def pull_remote!(remote, branch)
        return if skip_pull?

        pull_args = ENV.fetch('KK_GIT_PULL_ARGS', '--ff-only').split
        out, err, ok = run_cmd('git', 'pull', remote, branch, *pull_args)
        ensure_ok!(ok, 'git pull', stdout: out, stderr: err)
      end

      def push_remote!(remote, branch)
        return if skip_push?

        ensure_not_detached! unless dry_run?

        if upstream_configured?
          out, err, ok = run_cmd('git', 'push', remote, branch)
        else
          out, err, ok = run_cmd('git', 'push', '-u', remote, branch)
        end
        ensure_ok!(ok, 'git push', stdout: out, stderr: err)
      end

      def sync_with_remote!(remote, branch)
        pull_remote!(remote, branch)
        push_remote!(remote, branch)
        puts "Synced: #{remote} #{branch}" unless dry_run?
      end

      def add_all!
        paths = add_paths
        out, err, ok = run_cmd('git', 'add', *paths)
        ensure_ok!(ok, 'git add', stdout: out, stderr: err)
      end

      # @return [Boolean] commit 是否成功
      def commit_with_message!(message)
        commit_args = amend? ? %w[commit --amend -F] : %w[commit -F]

        Tempfile.create('commit_message') do |f|
          f.write(message)
          f.flush
          out, err, ok = run_cmd('git', *commit_args, f.path)
          if ok
            true
          elsif err.include?('nothing to commit') || out.include?('nothing to commit')
            puts 'No staged changes to commit'
            false
          else
            ensure_ok!(ok, 'git commit', stdout: out, stderr: err)
            false
          end
        end
      end

      # 自动 add → commit → pull → push 主流程
      #
      # @return [Symbol] :synced | :committed_and_synced | :noop
      def auto_commit_push!(commit_message_generator: nil)
        ensure_in_repo!
        remote_name = remote
        branch_name = branch

        if working_tree_clean?
          if status(remote: remote_name, branch: branch_name).needs_sync?
            sync_with_remote!(remote_name, branch_name)
            return :synced
          end

          puts 'No changes to commit or push'
          return :noop
        end

        add_all!

        message =
          if commit_message_generator
            commit_message_generator.call
          else
            KKGit::CommitMessage.generate(mode: :all)
          end
        message = message.to_s.strip
        message = "chore(repo): update project files\n\n#{Time.now}" if message.empty?

        committed = commit_with_message!(message)
        if committed || unpushed_commits?(remote_name, branch_name)
          sync_with_remote!(remote_name, branch_name)
          return committed ? :committed_and_synced : :synced
        end

        :noop
      end
    end
  end
end
