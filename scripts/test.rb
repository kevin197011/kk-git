#!/usr/bin/env ruby
# frozen_string_literal: true
# scripts/test.rb - kk-git 自动化测试（无交互）

require 'fileutils'
require 'open3'
require 'tempfile'

class TestRunner
  def initialize
    @project_root = File.expand_path('..', __dir__)
    @lib_path = File.join(@project_root, 'lib')
    @errors = []
  end

  def run
    puts '🚀 开始 kk-git 自动化测试...'

    test_commit_message_inference
    test_git_ops_in_temp_repo

    print_results
  end

  private

  def load_kkgit
    $LOAD_PATH.unshift(@lib_path) unless $LOAD_PATH.include?(@lib_path)
    require 'kk/git'
  end

  def assert(condition, message)
    @errors << message unless condition
  end

  def test_commit_message_inference
    puts '🧪 测试 CommitMessage 推断...'
    load_kkgit

    Dir.mktmpdir('kkgit-test') do |dir|
      init_repo(dir)
      write_file(dir, 'README.md', "# test\n")
      run_git(dir, 'add', 'README.md')

      msg = KKGit::CommitMessage.generate(repo_dir: dir, mode: :staged)
      assert(!msg.nil?, 'staged README 应生成 commit message')
      assert(msg.include?('docs'), "应为 docs 类型，实际: #{msg}")

      write_file(dir, 'lib/app.rb', "puts 'hi'\n")
      msg2 = KKGit::CommitMessage.generate(repo_dir: dir, mode: :worktree)
      assert(!msg2.nil?, 'worktree 变更应生成 commit message')
      assert(msg2.match?(/\A(feat|fix|chore)\(/), "应推断为 feat/fix/chore，实际: #{msg2}")

      hash = KKGit::CommitMessage.generate_hash(repo_dir: dir, mode: :worktree)
      assert(hash[:empty] == false, 'generate_hash 不应为空')
      assert(!hash[:header].to_s.empty?, 'generate_hash 应包含 header')
    end

    puts '✅ CommitMessage 测试通过'
  end

  def test_git_ops_in_temp_repo
    puts '🧪 测试 GitOps 流程...'
    load_kkgit

    Dir.mktmpdir('kkgit-ops') do |dir|
      init_repo(dir)
      write_file(dir, 'note.txt', "hello\n")
      run_git(dir, 'add', 'note.txt')
      run_git(dir, 'commit', '-m', 'init')

      Dir.chdir(dir) do
        s = KKGit::GitOps.status
        assert(s.clean, 'commit 后工作区应为 clean')
        assert(s.ahead.zero?, '无 remote 时 ahead 应为 0')
        assert(!s.detached, '不应处于 detached HEAD')

        write_file(dir, 'note.txt', "hello world\n")
        assert(!KKGit::GitOps.working_tree_clean?, '修改后工作区应为 dirty')

        ENV['KK_GIT_DRY_RUN'] = '1'
        result = KKGit::GitOps.auto_commit_push!
        assert(result == :committed_and_synced || result == :noop, "dry-run 应完成流程，实际: #{result}")
        ENV.delete('KK_GIT_DRY_RUN')

        assert(KKGit::GitOps.working_tree_clean? == false, 'dry-run 不应真正 commit')
      end
    end

    puts '✅ GitOps 测试通过'
  end

  def init_repo(dir)
    run_git(dir, 'init', '-b', 'main')
    run_git(dir, 'config', 'user.email', 'test@example.com')
    run_git(dir, 'config', 'user.name', 'Test User')
  end

  def write_file(dir, rel, content)
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def run_git(dir, *args)
    stdout, stderr, status = Open3.capture3('git', *args, chdir: dir)
    return stdout if status.success?

    raise "git #{args.join(' ')} failed in #{dir}: #{stderr}"
  end

  def print_results
    puts "\n#{'=' * 50}"
    if @errors.empty?
      puts '✅ 所有测试通过！'
      exit 0
    else
      puts '❌ 测试失败：'
      @errors.each { |error| puts "  - #{error}" }
      exit 1
    end
  end
end

TestRunner.new.run if __FILE__ == $PROGRAM_NAME
