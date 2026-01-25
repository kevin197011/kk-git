# frozen_string_literal: true

# Copyright (c) 2025 kk
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require 'time'
require 'open3'

# Prefer local lib/ when running from the repo (avoids loading an installed gem version).
$LOAD_PATH.unshift(File.join(__dir__, 'lib')) unless $LOAD_PATH.include?(File.join(__dir__, 'lib'))
begin
  require 'kk/git'
rescue LoadError
  require_relative 'lib/kk/git'
end
require_relative 'lib/kk/git/rake_tasks'

task default: %w[push]

def run_cmd(*cmd)
  stdout, stderr, status = Open3.capture3(*cmd)
  [stdout, stderr, status.success?]
end

def latest_semver_tag(prefix: 'v')
  stdout, _stderr, ok = run_cmd('git', 'tag', '--list', "#{prefix}[0-9]*.[0-9]*.[0-9]*", '--sort=-v:refname')
  return nil unless ok

  tag = stdout.to_s.split("\n").first
  tag&.strip
end

def parse_semver(str)
  m = str.to_s.match(/\A(\d+)\.(\d+)\.(\d+)\z/)
  return nil unless m

  [m[1].to_i, m[2].to_i, m[3].to_i]
end

def bump_semver(version, level)
  major, minor, patch = version
  case level
  when 'major'
    [major + 1, 0, 0]
  when 'minor'
    [major, minor + 1, 0]
  else
    [major, minor, patch + 1]
  end
end

def semver_to_s(v)
  "#{v[0]}.#{v[1]}.#{v[2]}"
end

def update_version_file!(new_version)
  path = File.join(__dir__, 'lib', 'kk', 'git', 'version.rb')
  content = File.read(path, mode: 'r:BOM|UTF-8')

  replaced = content.sub(/VERSION\s*=\s*'[^']*'/, "VERSION = '#{new_version}'")
  raise "Failed to update version: VERSION constant not found (#{path})" if replaced == content

  File.write(path, replaced)
end

def next_release_tag(prefix: 'v', bump: 'patch')
  current = KKGit::VERSION
  base =
    if (t = latest_semver_tag(prefix: prefix))
      parse_semver(t.delete_prefix(prefix)) || parse_semver(current) || [0, 1, 0]
    else
      parse_semver(current) || [0, 1, 0]
    end

  tag = nil
  version = base
  50.times do
    version = bump_semver(version, bump)
    candidate = "#{prefix}#{semver_to_s(version)}"
    out, _err, ok = run_cmd('git', 'tag', '--list', candidate)
    next unless ok

    if out.to_s.strip.empty?
      tag = candidate
      break
    end
  end
  raise 'Failed to generate next tag: too many attempts' if tag.nil?

  [tag, semver_to_s(version)]
end

task :push do
  # Check for changes
  status_output = `git status --porcelain 2>&1`
  if status_output.empty? || !$?.success?
    puts 'No changes to commit'
    exit 0
  end

  # Pull first (avoid tagging a commit that later gets merged)
  pull_output = `git pull 2>&1`
  unless $?.success?
    if pull_output.include?('conflict') || pull_output.include?('CONFLICT')
      puts 'Merge conflict detected. Please resolve and retry.'
      puts pull_output
      exit 1
    else
      puts 'git pull failed, continuing with commit/push'
      puts pull_output if pull_output.length > 0
    end
  end

  # Auto-increment tag (enabled by default)
  auto_tag = ENV.fetch('KK_GIT_AUTO_TAG', '1') != '0'
  bump_level = ENV.fetch('KK_GIT_BUMP', 'patch') # patch/minor/major
  tag_prefix = ENV.fetch('KK_GIT_TAG_PREFIX', 'v')

  tag = nil
  new_version = nil
  if auto_tag
    tag, new_version = next_release_tag(prefix: tag_prefix, bump: bump_level)
    update_version_file!(new_version)
    puts "Version bumped to #{new_version}, preparing tag #{tag}"
  end

  # Stage everything (including version bump)
  system 'git add .'

  # Generate commit message (from staged changes)
  commit_message = KKGit::CommitMessage.generate(mode: :staged) || "chore(repo): update project files\n\n#{Time.now}"

  # Write message to a temp file
  require 'tempfile'
  temp_file = Tempfile.new('commit_message')
  temp_file.write(commit_message)
  temp_file.close

  # Commit using the temp file
  success = system("git commit -F #{temp_file.path}")

  temp_file.unlink

  unless success
    puts 'Commit failed'
    exit 1
  end

  puts "Committed: #{commit_message.lines.first.chomp}"

  # Push to remote
  push_output = `git push origin main 2>&1`
  unless $?.success?
    puts 'Push failed'
    puts push_output
    exit 1
  end

  if auto_tag && tag
    tag_ok = system("git tag -a #{tag} -m \"Release #{tag}\"")
    unless tag_ok
      puts "Tag creation failed: #{tag}"
      exit 1
    end

    tag_push_output = `git push origin #{tag} 2>&1`
    unless $?.success?
      puts 'Tag push failed'
      puts tag_push_output
      exit 1
    end

    puts "Tag pushed: #{tag}"
  end

  puts 'Push succeeded'
end

task :run do
  system 'docker compose down -v'
  system 'docker compose up -d --build --remove-orphans'
  system 'docker compose logs -f'
end

# task :push do
#   system 'git add .'
#   system "git commit -m 'Update #{Time.now}'"
#   system 'git pull'
#   system 'git push origin main'
# end