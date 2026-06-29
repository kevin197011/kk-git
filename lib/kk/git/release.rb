# frozen_string_literal: true

module KKGit
  # Semver bump and git tag helpers (maintainer release flow).
  module Release
    VERSION_PATH = File.join(__dir__, 'version.rb').freeze

    module_function

    def latest_semver_tag(prefix: 'v', repo_dir: '.')
      stdout, _stderr, ok = GitOps.run_cmd(
        'git', 'tag', '--list', "#{prefix}[0-9]*.[0-9]*.[0-9]*", '--sort=-v:refname',
        chdir: repo_dir
      )
      return nil unless ok

      stdout.to_s.split("\n").first&.strip
    end

    def parse_semver(str)
      m = str.to_s.match(/\A(\d+)\.(\d+)\.(\d+)\z/)
      return nil unless m

      [m[1].to_i, m[2].to_i, m[3].to_i]
    end

    def bump_semver(version, level)
      major, minor, patch = version
      case level
      when 'major' then [major + 1, 0, 0]
      when 'minor' then [major, minor + 1, 0]
      else [major, minor, patch + 1]
      end
    end

    def semver_to_s(version)
      "#{version[0]}.#{version[1]}.#{version[2]}"
    end

    def update_version!(new_version)
      content = File.read(VERSION_PATH, mode: 'r:BOM|UTF-8')
      replaced = content.sub(/VERSION\s*=\s*'[^']*'/, "VERSION = '#{new_version}'")
      raise "Failed to update version in #{VERSION_PATH}" if replaced == content

      File.write(VERSION_PATH, replaced)
    end

    # @return [Array(String, String)] tag, version
    def next_tag_and_version(prefix: nil, bump: nil, repo_dir: '.')
      prefix ||= ENV.fetch('KK_GIT_TAG_PREFIX', 'v')
      bump ||= ENV.fetch('KK_GIT_BUMP', 'patch')
      current = KKGit::VERSION
      base =
        if (tag = latest_semver_tag(prefix: prefix, repo_dir: repo_dir))
          parse_semver(tag.delete_prefix(prefix)) || parse_semver(current) || [0, 1, 0]
        else
          parse_semver(current) || [0, 1, 0]
        end

      version = base
      50.times do
        version = bump_semver(version, bump)
        candidate = "#{prefix}#{semver_to_s(version)}"
        out, _err, ok = GitOps.run_cmd('git', 'tag', '--list', candidate, chdir: repo_dir)
        next unless ok && out.to_s.strip.empty?

        return [candidate, semver_to_s(version)]
      end

      raise 'Failed to generate next release tag: too many attempts'
    end

    def create_and_push_tag!(tag, remote: nil, repo_dir: '.')
      remote ||= GitOps.remote
      out, err, ok = GitOps.run_cmd('git', 'tag', '-a', tag, '-m', "Release #{tag}", chdir: repo_dir)
      GitOps.ensure_ok!(ok, 'git tag', stdout: out, stderr: err)

      out, err, ok = GitOps.run_cmd('git', 'push', remote, tag, chdir: repo_dir)
      GitOps.ensure_ok!(ok, 'git push tag', stdout: out, stderr: err)
    end
  end
end
