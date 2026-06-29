# frozen_string_literal: true

require 'open3'

module KKGit
  # Shared git subprocess helper for CommitMessage and GitOps.
  module GitRunner
    module_function

    def capture(args, repo_dir: '.')
      stdout, stderr, status = Open3.capture3('git', *args, chdir: repo_dir)
      [normalize_utf8(stdout), normalize_utf8(stderr), status.success?]
    end

    def capture!(args, repo_dir: '.')
      stdout, stderr, ok = capture(args, repo_dir: repo_dir)
      raise "git #{args.join(' ')} failed: #{stderr.strip}" unless ok

      stdout
    end

    def normalize_utf8(str)
      str.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD")
    end
  end
end
