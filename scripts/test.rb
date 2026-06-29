#!/usr/bin/env ruby
# frozen_string_literal: true

# scripts/test.rb - kk-git automated checks (no test framework)

require 'fileutils'
require 'json'
require 'open3'
require 'tempfile'

class TestRunner
  SENSITIVE_FIXTURE = '.env.local'

  def initialize
    @project_root = File.expand_path('..', __dir__)
    @lib_path = File.join(@project_root, 'lib')
    @errors = []
  end

  def run
    puts 'Running kk-git tests...'
    load_kkgit

    test_commit_message_inference
    test_breaking_change_detection
    test_rename_inference
    test_json_output
    test_default_code_type
    test_sensitive_paths
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
    puts 'Testing CommitMessage inference...'

    Dir.mktmpdir('kkgit-test') do |dir|
      init_repo(dir)
      write_file(dir, 'README.md', "# test\n")
      run_git(dir, 'add', 'README.md')

      msg = KKGit::CommitMessage.generate(repo_dir: dir, mode: :staged)
      assert(!msg.nil?, 'staged README should produce a commit message')
      assert(msg.include?('docs'), "expected docs type, got: #{msg}")

      write_file(dir, 'lib/app.rb', "puts 'hi'\n")
      msg2 = KKGit::CommitMessage.generate(repo_dir: dir, mode: :worktree)
      assert(!msg2.nil?, 'worktree changes should produce a commit message')
      assert(msg2.match?(/\A(feat|chore)\(/), "expected feat/chore for new code, got: #{msg2}")

      hash = KKGit::CommitMessage.generate_hash(repo_dir: dir, mode: :worktree)
      assert(hash[:empty] == false, 'generate_hash should not be empty')
      assert(!hash[:header].to_s.empty?, 'generate_hash should include header')
    end
  end

  def test_breaking_change_detection
    puts 'Testing breaking change detection...'

    Dir.mktmpdir('kkgit-breaking') do |dir|
      init_repo(dir)
      write_file(dir, 'lib/api.rb', "raise 'BREAKING CHANGE: removed endpoint'\n")
      run_git(dir, 'add', 'lib/api.rb')

      msg = KKGit::CommitMessage.generate(repo_dir: dir, mode: :staged)
      assert(msg.include?('!'), "breaking marker should produce '!', got: #{msg}")
    end
  end

  def test_rename_inference
    puts 'Testing rename inference...'

    Dir.mktmpdir('kkgit-rename') do |dir|
      init_repo(dir)
      write_file(dir, 'old_name.rb', "puts 1\n")
      run_git(dir, 'add', 'old_name.rb')
      run_git(dir, 'commit', '-m', 'init')
      run_git(dir, 'mv', 'old_name.rb', 'new_name.rb')

      msg = KKGit::CommitMessage.generate(repo_dir: dir, mode: :all)
      assert(msg.include?('Rename'), "rename should be detected, got: #{msg}")
      assert(msg.include?('old_name.rb'), "rename body should mention old path, got: #{msg}")
    end
  end

  def test_json_output
    puts 'Testing JSON output...'

    Dir.mktmpdir('kkgit-json') do |dir|
      init_repo(dir)
      write_file(dir, 'notes.md', "hello\n")
      run_git(dir, 'add', 'notes.md')

      hash = KKGit::CommitMessage.generate_hash(repo_dir: dir, mode: :staged)
      parsed = JSON.parse(hash.to_json)
      assert(parsed['type'] == 'docs', "json type should be docs, got: #{parsed['type']}")
      assert(!parsed['header'].to_s.empty?, 'json header should be present')
    end
  end

  def test_default_code_type
    puts 'Testing KK_GIT_DEFAULT_TYPE...'

    Dir.mktmpdir('kkgit-default-type') do |dir|
      init_repo(dir)
      write_file(dir, 'src/widget.rb', "x = 1\n")
      run_git(dir, 'add', 'src/widget.rb')
      run_git(dir, 'commit', '-m', 'init')
      write_file(dir, 'src/widget.rb', "x = 2\n")

      ENV['KK_GIT_DEFAULT_TYPE'] = 'refactor'
      msg = KKGit::CommitMessage.generate(repo_dir: dir, mode: :worktree)
      ENV.delete('KK_GIT_DEFAULT_TYPE')
      assert(msg.start_with?('refactor('), "default type should be refactor, got: #{msg}")
    end
  end

  def test_sensitive_paths
    puts 'Testing sensitive path guard...'

    Dir.mktmpdir('kkgit-sensitive') do |dir|
      init_repo(dir)
      write_file(dir, 'note.txt', "hello\n")
      run_git(dir, 'add', 'note.txt')
      run_git(dir, 'commit', '-m', 'init')

      write_file(dir, SENSITIVE_FIXTURE, 'SECRET=1')
      KKGit::GitOps.add_all!(repo_dir: dir)
      paths = KKGit::GitOps.sensitive_staged_paths(repo_dir: dir)
      assert(paths.include?(SENSITIVE_FIXTURE), 'should detect sensitive staged path')

      raised = false
      begin
        KKGit::GitOps.ensure_no_sensitive_staged!(repo_dir: dir)
      rescue KKGit::GitOps::Error
        raised = true
      end
      assert(raised, 'should refuse sensitive paths by default')
    end
  end

  def test_git_ops_in_temp_repo
    puts 'Testing GitOps flow...'

    Dir.mktmpdir('kkgit-ops') do |dir|
      init_repo(dir)
      write_file(dir, 'note.txt', "hello\n")
      run_git(dir, 'add', 'note.txt')
      run_git(dir, 'commit', '-m', 'init')

      Dir.chdir(dir) do
        s = KKGit::GitOps.status(repo_dir: dir)
        assert(s.clean, 'working tree should be clean after commit')
        assert(s.ahead.zero?, 'ahead should be 0 without remote')
        assert(!s.detached, 'should not be detached HEAD')

        write_file(dir, 'note.txt', "hello world\n")
        assert(!KKGit::GitOps.working_tree_clean?(repo_dir: dir), 'modified tree should be dirty')

        ENV['KK_GIT_DRY_RUN'] = '1'
        result = KKGit::GitOps.auto_commit_push!(repo_dir: dir)
        assert(%i[committed_and_synced noop synced].include?(result),
               "dry-run should finish flow, got: #{result}")
        ENV.delete('KK_GIT_DRY_RUN')

        assert(KKGit::GitOps.working_tree_clean?(repo_dir: dir) == false, 'dry-run should not commit')
      end
    end
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
      puts 'All tests passed.'
      exit 0
    end

    puts 'Test failures:'
    @errors.each { |error| puts "  - #{error}" }
    exit 1
  end
end

TestRunner.new.run if __FILE__ == $PROGRAM_NAME
