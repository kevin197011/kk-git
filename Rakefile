# frozen_string_literal: true

# Copyright (c) 2025 kk
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require 'time'
require 'open3'
begin
  require 'kk/git'
rescue LoadError
  require_relative 'lib/kk/git'
end

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
  raise "无法更新版本号：未找到 VERSION 常量（#{path}）" if replaced == content

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
  raise '无法生成递增 tag：尝试次数过多' if tag.nil?

  [tag, semver_to_s(version)]
end

namespace :git do
  desc '根据暂存区变更生成 commit message（Conventional Commits）'
  task :commit_message do
    msg = KKGit::CommitMessage.generate(mode: :staged)
    puts(msg || '')
    exit(msg.nil? ? 1 : 0)
  end

  desc '根据工作区变更生成 commit message（含 untracked）'
  task :commit_message_worktree do
    msg = KKGit::CommitMessage.generate(mode: :worktree)
    puts(msg || '')
    exit(msg.nil? ? 1 : 0)
  end

  desc '合并暂存区+工作区变更生成 commit message'
  task :commit_message_all do
    msg = KKGit::CommitMessage.generate(mode: :all)
    puts(msg || '')
    exit(msg.nil? ? 1 : 0)
  end
end

task :push do
  # 检查是否有变更
  status_output = `git status --porcelain 2>&1`
  if status_output.empty? || !$?.success?
    puts '没有变更需要提交'
    exit 0
  end

  # 先拉取最新代码（避免提交后再合并导致 tag 指向不一致）
  pull_output = `git pull 2>&1`
  unless $?.success?
    if pull_output.include?('conflict') || pull_output.include?('CONFLICT')
      puts '❌ 检测到合并冲突，请手动解决后重试'
      puts pull_output
      exit 1
    else
      puts '⚠️  拉取失败，但继续提交/推送'
      puts pull_output if pull_output.length > 0
    end
  end

  # 自动生成递增 tag（默认开启）
  auto_tag = ENV.fetch('KK_GIT_AUTO_TAG', '1') != '0'
  bump_level = ENV.fetch('KK_GIT_BUMP', 'patch') # patch/minor/major
  tag_prefix = ENV.fetch('KK_GIT_TAG_PREFIX', 'v')

  tag = nil
  new_version = nil
  if auto_tag
    tag, new_version = next_release_tag(prefix: tag_prefix, bump: bump_level)
    update_version_file!(new_version)
    puts "🔖 版本号更新为 #{new_version}，准备创建 tag #{tag}"
  end

  # 添加所有变更（包含版本号更新）
  system 'git add .'

  # 生成智能 commit message（基于暂存区）
  commit_message = KKGit::CommitMessage.generate(mode: :staged) || "chore(repo): 更新项目文件\n\n#{Time.now}"

  # 创建临时文件存储 commit message
  require 'tempfile'
  temp_file = Tempfile.new('commit_message')
  temp_file.write(commit_message)
  temp_file.close

  # 使用临时文件提交
  success = system("git commit -F #{temp_file.path}")

  temp_file.unlink

  unless success
    puts '提交失败'
    exit 1
  end

  puts "✅ 提交成功: #{commit_message.lines.first.chomp}"

  # 推送到远程
  push_output = `git push origin main 2>&1`
  unless $?.success?
    puts '❌ 推送失败'
    puts push_output
    exit 1
  end

  if auto_tag && tag
    tag_ok = system("git tag -a #{tag} -m \"Release #{tag}\"")
    unless tag_ok
      puts "❌ 创建 tag 失败: #{tag}"
      exit 1
    end

    tag_push_output = `git push origin #{tag} 2>&1`
    unless $?.success?
      puts '❌ 推送 tag 失败'
      puts tag_push_output
      exit 1
    end

    puts "✅ tag 已推送: #{tag}"
  end

  puts '✅ 推送成功'
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