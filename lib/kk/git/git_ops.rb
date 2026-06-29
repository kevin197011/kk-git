# frozen_string_literal: true

require 'tempfile'
require_relative 'git_runner'

module KKGit
  # Git 仓库操作：供 Rake task 与 CLI 复用。
  module GitOps
    class Error < StandardError; end

    SENSITIVE_PATH_PATTERNS = [
      %r{\A\.env(\.|$)}i,
      /credentials/i,
      %r{\.pem\z}i,
      /id_rsa/i,
      %r{\.key\z}i,
      %r{\Asecrets?\.}i
    ].freeze

    # 仓库同步状态快照
    Status = Struct.new(
      :branch, :remote, :clean, :ahead, :behind,
      :upstream_configured, :detached,
      keyword_init: true
    ) do
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

      def branch(explicit: ENV['KK_GIT_BRANCH'], repo_dir: '.')
        explicit.to_s.strip.empty? ? current_branch(repo_dir: repo_dir) : explicit.to_s.strip
      end

      def add_paths
        ENV.fetch('KK_GIT_ADD_PATHS', '.').split(/\s+/).reject(&:empty?)
      end

      MUTATING_GIT_COMMANDS = %w[add commit push pull merge rebase checkout reset cherry-pick revert tag].freeze

      def run_cmd(*cmd, chdir: '.')
        if dry_run? && mutating_git_command?(cmd)
          label = chdir == '.' ? cmd.join(' ') : "(cd #{chdir} && #{cmd.join(' ')})"
          puts "[dry-run] #{label}"
          return ['', '', true]
        end

        if cmd[0] == 'git'
          stdout, stderr, ok = GitRunner.capture(cmd.drop(1), repo_dir: chdir)
        else
          require 'open3'
          stdout, stderr, status = Open3.capture3(*cmd, chdir: chdir == '.' ? nil : chdir)
          ok = status.success?
          stdout = GitRunner.normalize_utf8(stdout)
          stderr = GitRunner.normalize_utf8(stderr)
        end
        [stdout.to_s, stderr.to_s, ok]
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

      def in_git_repo?(repo_dir: '.')
        _, _, ok = run_cmd('git', 'rev-parse', '--git-dir', chdir: repo_dir)
        ok
      end

      def ensure_in_repo!(repo_dir: '.')
        raise Error, 'Not a git repository' unless in_git_repo?(repo_dir: repo_dir)
      end

      def current_branch(repo_dir: '.')
        out, err, ok = run_cmd('git', 'rev-parse', '--abbrev-ref', 'HEAD', chdir: repo_dir)
        ensure_ok!(ok, 'Get current branch', stdout: out, stderr: err)
        out.strip
      end

      def detached_head?(repo_dir: '.')
        current_branch(repo_dir: repo_dir) == 'HEAD'
      end

      def ensure_not_detached!(repo_dir: '.')
        raise Error, 'Cannot push from detached HEAD' if detached_head?(repo_dir: repo_dir)
      end

      def working_tree_clean?(repo_dir: '.')
        out, err, ok = run_cmd('git', 'status', '--porcelain', chdir: repo_dir)
        ensure_ok!(ok, 'Check git status', stdout: out, stderr: err)
        out.strip.empty?
      end

      def upstream_configured?(repo_dir: '.')
        _, _, ok = run_cmd('git', 'rev-parse', '--abbrev-ref', '@{u}', chdir: repo_dir)
        ok
      end

      def ahead_count(remote, branch, repo_dir: '.')
        out, _err, ok = run_cmd('git', 'rev-list', '--count', '@{u}..HEAD', chdir: repo_dir)
        return out.strip.to_i if ok

        out, _err, ok = run_cmd('git', 'rev-list', '--count', "#{remote}/#{branch}..HEAD", chdir: repo_dir)
        return out.strip.to_i if ok

        0
      end

      def behind_count(remote, branch, repo_dir: '.')
        out, _err, ok = run_cmd('git', 'rev-list', '--count', 'HEAD..@{u}', chdir: repo_dir)
        return out.strip.to_i if ok

        out, _err, ok = run_cmd('git', 'rev-list', '--count', "HEAD..#{remote}/#{branch}", chdir: repo_dir)
        return out.strip.to_i if ok

        0
      end

      def unpushed_commits?(remote, branch, repo_dir: '.')
        ahead_count(remote, branch, repo_dir: repo_dir).positive?
      end

      def status(remote: nil, branch: nil, repo_dir: '.')
        ensure_in_repo!(repo_dir: repo_dir)
        remote ||= self.remote
        branch ||= self.branch(repo_dir: repo_dir)

        Status.new(
          branch: branch,
          remote: remote,
          clean: working_tree_clean?(repo_dir: repo_dir),
          ahead: ahead_count(remote, branch, repo_dir: repo_dir),
          behind: behind_count(remote, branch, repo_dir: repo_dir),
          upstream_configured: upstream_configured?(repo_dir: repo_dir),
          detached: detached_head?(repo_dir: repo_dir)
        )
      end

      def status_hash(remote: nil, branch: nil, repo_dir: '.')
        s = status(remote: remote, branch: branch, repo_dir: repo_dir)
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

      def pull_remote!(remote, branch, repo_dir: '.')
        return if skip_pull?

        pull_args = ENV.fetch('KK_GIT_PULL_ARGS', '--ff-only').split
        out, err, ok = run_cmd('git', 'pull', remote, branch, *pull_args, chdir: repo_dir)
        ensure_ok!(ok, 'git pull', stdout: out, stderr: err)
      end

      def push_remote!(remote, branch, repo_dir: '.')
        return if skip_push?

        ensure_not_detached!(repo_dir: repo_dir) unless dry_run?

        if upstream_configured?(repo_dir: repo_dir)
          out, err, ok = run_cmd('git', 'push', remote, branch, chdir: repo_dir)
        else
          out, err, ok = run_cmd('git', 'push', '-u', remote, branch, chdir: repo_dir)
        end
        ensure_ok!(ok, 'git push', stdout: out, stderr: err)
      end

      def sync_with_remote!(remote, branch, repo_dir: '.')
        pull_remote!(remote, branch, repo_dir: repo_dir)
        push_remote!(remote, branch, repo_dir: repo_dir)
        puts "Synced: #{remote} #{branch}" unless dry_run?
      end

      def add_all!(repo_dir: '.')
        paths = add_paths
        out, err, ok = run_cmd('git', 'add', *paths, chdir: repo_dir)
        ensure_ok!(ok, 'git add', stdout: out, stderr: err)
      end

      def sensitive_path?(path)
        SENSITIVE_PATH_PATTERNS.any? { |pattern| path.match?(pattern) }
      end

      def sensitive_staged_paths(repo_dir: '.')
        out, _err, ok = run_cmd('git', 'diff', '--cached', '--name-only', chdir: repo_dir)
        return [] unless ok

        out.split("\n").reject(&:empty?).select { |path| sensitive_path?(path) }
      end

      def ensure_no_sensitive_staged!(repo_dir: '.')
        paths = sensitive_staged_paths(repo_dir: repo_dir)
        return if paths.empty?

        if ENV['KK_GIT_ALLOW_SENSITIVE'] == '1'
          warn "Warning: committing sensitive paths: #{paths.join(', ')}"
        else
          raise Error,
                "Refusing to commit sensitive paths: #{paths.join(', ')}. " \
                'Set KK_GIT_ALLOW_SENSITIVE=1 to override.'
        end
      end

      def confirm_commit!(message)
        return unless ENV['KK_GIT_CONFIRM'] == '1'
        return if ENV['KK_GIT_YES'] == '1'

        puts "Commit message:\n#{message}\n"
        raise Error, 'Set KK_GIT_YES=1 to confirm this commit'
      end

      def commit_with_message!(message, repo_dir: '.')
        commit_args = amend? ? %w[commit --amend -F] : %w[commit -F]

        Tempfile.create('commit_message') do |f|
          f.write(message)
          f.flush
          out, err, ok = run_cmd('git', *commit_args, f.path, chdir: repo_dir)
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

      # @return [Symbol] :synced | :committed_and_synced | :noop
      def auto_commit_push!(commit_message_generator: nil, repo_dir: '.')
        ensure_in_repo!(repo_dir: repo_dir)
        remote_name = remote
        branch_name = branch(repo_dir: repo_dir)

        if working_tree_clean?(repo_dir: repo_dir)
          if status(remote: remote_name, branch: branch_name, repo_dir: repo_dir).needs_sync?
            sync_with_remote!(remote_name, branch_name, repo_dir: repo_dir)
            return :synced
          end

          puts 'No changes to commit or push'
          return :noop
        end

        add_all!(repo_dir: repo_dir)
        ensure_no_sensitive_staged!(repo_dir: repo_dir)

        message =
          if commit_message_generator
            commit_message_generator.call
          else
            KKGit::CommitMessage.generate(repo_dir: repo_dir, mode: :all)
          end
        message = message.to_s.strip
        raise Error, 'Could not generate commit message from staged changes' if message.empty?

        confirm_commit!(message)

        committed = commit_with_message!(message, repo_dir: repo_dir)
        if committed || unpushed_commits?(remote_name, branch_name, repo_dir: repo_dir)
          sync_with_remote!(remote_name, branch_name, repo_dir: repo_dir)
          return committed ? :committed_and_synced : :synced
        end

        :noop
      end
    end
  end
end
