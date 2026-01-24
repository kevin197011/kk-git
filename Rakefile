# frozen_string_literal: true

# Copyright (c) 2025 kk
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require 'time'
begin
  require 'kk/git'
rescue LoadError
  require_relative 'lib/kk/git'
end

task default: %w[push]

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

  # 添加所有变更
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

  # 拉取最新代码
  pull_output = `git pull 2>&1`
  unless $?.success?
    if pull_output.include?('conflict') || pull_output.include?('CONFLICT')
      puts '❌ 检测到合并冲突，请手动解决后重试'
      puts pull_output
      exit 1
    else
      puts '⚠️  拉取失败，但继续推送'
      puts pull_output if pull_output.length > 0
    end
  end

  # 推送到远程
  push_output = `git push origin main 2>&1`
  unless $?.success?
    puts '❌ 推送失败'
    puts push_output
    exit 1
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