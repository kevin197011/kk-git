# frozen_string_literal: true

# Copyright (c) 2025 kk
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

$LOAD_PATH.unshift(File.join(__dir__, 'lib')) unless $LOAD_PATH.include?(File.join(__dir__, 'lib'))
begin
  require 'kk/git'
rescue LoadError
  require_relative 'lib/kk/git'
end
require_relative 'lib/kk/git/rake_tasks'

task default: %w[push]

desc 'Auto commit, pull, push (optional version bump + tag via KK_GIT_AUTO_TAG)'
task :push do
  auto_tag = ENV.fetch('KK_GIT_AUTO_TAG', '1') != '0'
  release_tag = nil
  status = KKGit::GitOps.status

  if status.clean && !status.needs_sync?
    puts 'No changes to commit or push'
    next
  end

  if auto_tag && !status.clean
    release_tag, new_version = KKGit::Release.next_tag_and_version
    KKGit::Release.update_version!(new_version)
    puts "Version bumped to #{new_version}, preparing tag #{release_tag}"
  end

  result = KKGit::GitOps.auto_commit_push!
  case result
  when :noop
    puts 'Nothing to do'
  when :synced, :committed_and_synced
    if release_tag
      KKGit::Release.create_and_push_tag!(release_tag)
      puts "Tag pushed: #{release_tag}"
    end
    puts 'Push succeeded'
  end
rescue KKGit::GitOps::Error => e
  warn e.message
  exit 1
end

desc 'Bump version, commit, push, and tag (same as push with KK_GIT_AUTO_TAG=1)'
task release: :push
