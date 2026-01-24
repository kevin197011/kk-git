# frozen_string_literal: true

require 'json'
require 'open3'

module KKGit
  # 根据当前 repo 的变更生成 Conventional Commits 信息。
  #
  # - 支持暂存区（staged）和工作区（working tree）变更
  # - 支持识别 untracked 文件
  # - 输出格式："<type>(<scope>): <subject>\n\n<body>"
  class CommitMessage
    # 变更条目（支持 rename/copy 的 old/new）
    Change = Struct.new(:status, :path, :old_path, :source, keyword_init: true)

    TYPE_PRIORITY = {
      'feat' => 1,
      'fix' => 2,
      'docs' => 3,
      'refactor' => 4,
      'style' => 5,
      'perf' => 6,
      'test' => 7,
      'ci' => 8,
      'chore' => 9
    }.freeze

    # 生成 commit message。
    #
    # @param repo_dir [String] Git 仓库目录（默认当前目录）
    # @param mode [Symbol] :staged（仅暂存区）/:worktree（仅工作区）/:all（两者合并）
    # @param include_body [Boolean] 多文件时是否输出 body（文件列表）
    # @param fallback_scope [String] 无法推断 scope 时的默认值
    # @param type_override [String, nil] 强制指定 type（如 feat/fix/docs）
    # @param scope_override [String, nil] 强制指定 scope
    # @param subject_override [String, nil] 强制指定 subject
    # @param detect_breaking [Boolean] 是否从 diff 中检测 BREAKING 标记并生成 "type(scope)!:"（默认 true）
    # @param max_diff_bytes [Integer] diff 检测的最大字节数（防止超大仓库导致变慢）
    #
    # @return [String, nil] 无变更时返回 nil
    def self.generate(
      repo_dir: '.',
      mode: :staged,
      include_body: true,
      fallback_scope: 'general',
      type_override: nil,
      scope_override: nil,
      subject_override: nil,
      detect_breaking: true,
      max_diff_bytes: 300_000
    )
      changes = collect_changes(repo_dir: repo_dir, mode: mode)
      return nil if changes.empty?

      inferred = infer(changes: changes, repo_dir: repo_dir, mode: mode, detect_breaking: detect_breaking,
                       max_diff_bytes: max_diff_bytes, fallback_scope: fallback_scope)

      type = (type_override || ENV['KK_GIT_TYPE'] || inferred[:type]).to_s.strip
      scope = (scope_override || ENV['KK_GIT_SCOPE'] || inferred[:scope]).to_s.strip
      subject = (subject_override || ENV['KK_GIT_SUBJECT'] || inferred[:subject]).to_s.strip

      bang = inferred[:breaking] ? '!' : ''
      message = +"#{type}(#{scope})#{bang}: #{subject}"
      if include_body && changes.length > 1
        message << "\n\n"
        message << generate_body(changes)
      end

      message
    end

    # 生成结构化信息（便于脚本/CI 消费）。
    #
    # @return [Hash]
    def self.generate_hash(
      repo_dir: '.',
      mode: :staged,
      include_body: true,
      fallback_scope: 'general',
      type_override: nil,
      scope_override: nil,
      subject_override: nil,
      detect_breaking: true,
      max_diff_bytes: 300_000
    )
      changes = collect_changes(repo_dir: repo_dir, mode: mode)
      return { empty: true } if changes.empty?

      inferred = infer(changes: changes, repo_dir: repo_dir, mode: mode, detect_breaking: detect_breaking,
                       max_diff_bytes: max_diff_bytes, fallback_scope: fallback_scope)

      type = (type_override || ENV['KK_GIT_TYPE'] || inferred[:type]).to_s.strip
      scope = (scope_override || ENV['KK_GIT_SCOPE'] || inferred[:scope]).to_s.strip
      subject = (subject_override || ENV['KK_GIT_SUBJECT'] || inferred[:subject]).to_s.strip

      header = "#{type}(#{scope})#{inferred[:breaking] ? '!' : ''}: #{subject}"
      body = include_body && changes.length > 1 ? generate_body(changes) : nil

      {
        empty: false,
        type: type,
        scope: scope,
        breaking: inferred[:breaking],
        subject: subject,
        header: header,
        body: body,
        changes: changes.map do |c|
          {
            status: c.status,
            path: c.path,
            old_path: c.old_path,
            source: c.source
          }
        end
      }
    end

    def self.collect_changes(repo_dir:, mode:)
      staged = (mode == :staged || mode == :all)
      worktree = (mode == :worktree || mode == :all)

      changes = []
      if staged
        changes.concat(parse_name_status_z(run_git(%w[diff --cached --name-status -z], repo_dir: repo_dir),
                                           source: 'staged'))
      end
      if worktree
        changes.concat(parse_name_status_z(run_git(%w[diff --name-status -z], repo_dir: repo_dir),
                                           source: 'worktree'))
      end

      if worktree
        untracked = run_git(%w[ls-files --others --exclude-standard -z], repo_dir: repo_dir)
        untracked.split("\0").each do |path|
          next if path.nil? || path.empty?
          changes << Change.new(status: 'A', path: path, old_path: nil, source: 'untracked')
        end
      end

      normalize_and_dedup(changes)
    end

    def self.parse_name_status_z(output, source:)
      tokens = output.to_s.split("\0")
      idx = 0
      changes = []
      while idx < tokens.length
        token = tokens[idx]
        break if token.nil? || token.empty?

        status_token = token
        status_char = status_token[0] # 'A' 'M' 'D' 'R' 'C' ...

        case status_char
        when 'R', 'C'
          old_path = tokens[idx + 1]
          new_path = tokens[idx + 2]
          break if old_path.nil? || new_path.nil?
          changes << Change.new(status: status_char, path: new_path, old_path: old_path, source: source)
          idx += 3
        else
          path = tokens[idx + 1]
          break if path.nil?
          changes << Change.new(status: status_char, path: path, old_path: nil, source: source)
          idx += 2
        end
      end
      changes
    end

    def self.normalize_and_dedup(changes)
      # key 维度：new_path；同一路径可能在 staged + worktree 都出现
      dedup = {}
      changes.each do |c|
        next if c.path.nil? || c.path.strip.empty?

        key = c.path
        existing = dedup[key]
        if existing.nil?
          dedup[key] = c
          next
        end

        # 优先级：
        # - staged 覆盖 worktree（更贴近即将提交的内容）
        # - rename/copy 优先于普通修改
        # - A(新增) 优先于 M
        priority = change_priority(c)
        existing_priority = change_priority(existing)
        dedup[key] = c if priority < existing_priority
      end

      dedup.values.sort_by(&:path)
    end

    def self.change_priority(change)
      source_p = case change.source
                 when 'staged' then 1
                 when 'worktree' then 2
                 when 'untracked' then 3
                 else 9
                 end
      status_p = case change.status
                 when 'R', 'C' then 1
                 when 'A' then 2
                 when 'D' then 3
                 when 'M' then 4
                 else 9
                 end
      source_p * 10 + status_p
    end

    def self.run_git(args, repo_dir:)
      stdout, stderr, status = Open3.capture3('git', *args, chdir: repo_dir)
      # Open3 返回的 stdout/stderr 可能是 ASCII-8BIT（BINARY），统一转为 UTF-8 避免拼接时报编码错误。
      stdout = stdout.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: '�')
      stderr = stderr.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: '�')

      raise "git #{args.join(' ')} 失败: #{stderr.strip}" unless status.success?

      stdout
    end

    # 推断 type/scope/subject（含 breaking 检测）
    #
    # @return [Hash] {:type,:scope,:subject,:breaking}
    def self.infer(changes:, repo_dir:, mode:, detect_breaking:, max_diff_bytes:, fallback_scope:)
      paths = changes.map(&:path)
      scope = infer_scope(paths, fallback_scope: fallback_scope)
      type = infer_type(changes)
      subject = generate_subject(type: type, changes: changes, scope: scope)
      breaking = detect_breaking ? detect_breaking_change(repo_dir: repo_dir, mode: mode, max_diff_bytes: max_diff_bytes) : false

      { type: type, scope: scope, subject: subject, breaking: breaking }
    end

    def self.pick_main_type(types)
      types.min_by { |t| TYPE_PRIORITY[t] || 999 } || 'chore'
    end

    def self.pick_scope(scopes, fallback_scope:)
      uniq = scopes.compact.uniq
      return fallback_scope if uniq.empty?
      return uniq.first if uniq.length == 1

      # 多 scope 的时候，尽量选 repo；否则 fallback
      return 'repo' if uniq.include?('repo')

      fallback_scope
    end

    def self.infer_scope(paths, fallback_scope:)
      # 工具/脚本类变更：尽量统一 scope 为 tools
      if paths.any? && paths.all? { |p| tooling_path?(p) || doc_path?(p) || ci_path?(p) }
        return 'tools'
      end

      tops = paths.map { |p| top_level_scope(p) }.compact
      uniq = tops.uniq
      return fallback_scope if uniq.empty?
      return uniq.first if uniq.length == 1
      return 'repo' if uniq.include?('repo')

      # 多个顶层目录：统一落到 repo（避免 scope 过长/不稳定）
      'repo'
    end

    def self.top_level_scope(path)
      return 'repo' if path.nil? || path.empty?
      return 'ci' if path.start_with?('.github/')
      return 'openspec' if path.start_with?('openspec/')
      return 'repo' unless path.include?('/')

      path.split('/', 2).first
    end

    def self.infer_type(changes)
      paths = changes.map(&:path)

      # 快速类别判断
      only_docs = paths.all? { |p| doc_path?(p) }
      return 'docs' if only_docs

      only_ci = paths.all? { |p| ci_path?(p) }
      return 'ci' if only_ci

      only_tests = paths.all? { |p| test_path?(p) || doc_path?(p) }
      return 'test' if only_tests && paths.any? { |p| test_path?(p) }

      only_deps = paths.all? { |p| deps_path?(p) }
      return 'chore' if only_deps

      # 工具/脚本/构建相关：倾向 chore（即便新增代码文件）
      if paths.any? && paths.all? { |p| tooling_path?(p) || doc_path?(p) || ci_path?(p) || deps_path?(p) }
        return 'chore'
      end

      # 代码变更的启发式：新增更偏 feat；否则若命中 fix 关键词则 fix；否则 refactor/chore
      has_code = paths.any? { |p| code_path?(p) }
      has_new_code = changes.any? { |c| c.status == 'A' && code_path?(c.path) }
      has_fix_keyword = paths.any? { |p| p.match?(/fix|bug|error|issue/i) }
      has_delete = changes.any? { |c| c.status == 'D' }

      return 'feat' if has_new_code
      return 'fix' if has_code && has_fix_keyword
      return 'refactor' if has_code && has_delete

      # 混合场景：按优先级聚合
      types = changes.map { |c| type_by_path(c.path) }
      pick_main_type(types)
    end

    def self.type_by_path(path)
      return 'docs' if doc_path?(path)
      return 'ci' if ci_path?(path)
      return 'test' if test_path?(path)
      return 'chore' if deps_path?(path)
      return 'chore' if build_path?(path)
      return 'chore' if config_path?(path)
      return 'chore' if script_path?(path)

      return 'chore' unless code_path?(path)

      # 默认：代码修改更接近 fix（更保守）；新增则在 infer_type 中处理为 feat
      'fix'
    end

    def self.doc_path?(path)
      return false if path.nil?
      path.start_with?('openspec/') ||
        path.match?(/\AREADME(\..+)?\z/i) ||
        path.match?(/\.(md|mdx|txt)\z/i)
    end

    def self.ci_path?(path)
      return false if path.nil?
      path.start_with?('.github/') ||
        path.match?(/\A\.gitlab-ci\.yml\z/i) ||
        path.start_with?('.circleci/') ||
        path.match?(/\A\.travis\.yml\z/i)
    end

    def self.test_path?(path)
      return false if path.nil?
      path.start_with?('spec/') ||
        path.start_with?('test/') ||
        path.include?('__tests__/') ||
        path.match?(/(_spec\.rb|_test\.(rb|go|js|ts|tsx))\z/i)
    end

    def self.deps_path?(path)
      return false if path.nil?
      path.match?(/\AGemfile(\.lock)?\z/i) ||
        path.match?(/\.gemspec\z/i) ||
        path.match?(/\Apackage\.json\z/i) ||
        path.match?(/\Ayarn\.lock\z/i) ||
        path.match?(/\Apnpm-lock\.yaml\z/i) ||
        path.match?(/\Apackage-lock\.json\z/i) ||
        path.match?(/\Ago\.mod\z/i) ||
        path.match?(/\Ago\.sum\z/i)
    end

    def self.build_path?(path)
      return false if path.nil?
      path.match?(/\ADockerfile(\..+)?\z/i) ||
        path.match?(/\Adocker-compose(\..+)?\.(yml|yaml)\z/i) ||
        path.match?(/\AMakefile\z/i) ||
        path.match?(/\ARakefile\z/i)
    end

    def self.config_path?(path)
      return false if path.nil?
      path.start_with?('config/') ||
        path.match?(/\A\.gitignore\z/i) ||
        path.match?(/\A\.rubocop(\.yml)?\z/i) ||
        path.match?(/\A\.rubocop_todo\.yml\z/i) ||
        path.match?(/\A\.editorconfig\z/i) ||
        path.match?(/\A\.tool-versions\z/i) ||
        path.match?(/\A\.env(\..+)?\z/i) ||
        path.match?(/\A\.env\.example\z/i) ||
        path.match?(/\.(toml|ini)\z/i)
    end

    def self.script_path?(path)
      return false if path.nil?
      path.start_with?('scripts/') ||
        path.match?(/\.(sh|bash)\z/i) ||
        path.match?(/\Adeploy\.sh\z/i)
    end

    def self.tooling_path?(path)
      return false if path.nil?
      build_path?(path) ||
        script_path?(path) ||
        path.start_with?('exe/') ||
        path.start_with?('lib/') ||
        path.match?(/\A[^\/]+\.rb\z/i) ||
        deps_path?(path) ||
        config_path?(path)
    end

    def self.code_path?(path)
      return false if path.nil?
      path.match?(/\.(rb|go|ts|tsx|js|jsx|py|java|kt|rs)\z/i)
    end

    def self.generate_subject(type:, changes:, scope:)
      if changes.length == 1
        c = changes.first
        action =
          case c.status
          when 'A' then '新增'
          when 'D' then '删除'
          when 'R' then '重命名'
          when 'C' then '复制'
          else '更新'
          end

        if %w[R C].include?(c.status) && c.old_path
          return "#{action} #{File.basename(c.old_path)} -> #{File.basename(c.path)}"
        end
        return "#{action} #{File.basename(c.path)}"
      end

      label =
        case scope
        when 'repo' then '项目'
        when 'tools' then '工具'
        else scope
        end

      case type
      when 'feat' then "添加#{label}功能"
      when 'fix' then "修复#{label}问题"
      when 'docs' then "更新#{label}文档"
      when 'refactor' then "重构#{label}代码"
      when 'style' then "调整#{label}代码格式"
      when 'perf' then "优化#{label}性能"
      when 'test' then "更新#{label}测试"
      when 'ci' then "更新#{label}CI配置"
      else "维护#{label}"
      end
    end

    def self.generate_body(changes)
      groups = {
        'A' => [],
        'M' => [],
        'D' => [],
        'R' => [],
        'C' => [],
        '?' => []
      }

      changes.each do |c|
        key = groups.key?(c.status) ? c.status : '?'
        groups[key] << c
      end

      lines = []
      append_group(lines, '新增', groups['A'])
      append_group(lines, '修改', groups['M'])
      append_group(lines, '删除', groups['D'])
      append_group(lines, '重命名', groups['R'])
      append_group(lines, '复制', groups['C'])
      append_group(lines, '其他', groups['?'])
      lines.join("\n")
    end

    def self.append_group(lines, title, items)
      return if items.empty?

      lines << "#{title}:"
      items.each do |c|
        if %w[R C].include?(c.status) && c.old_path
          lines << "  - #{c.old_path} -> #{c.path}"
        else
          lines << "  - #{c.path}"
        end
      end
    end

    def self.detect_breaking_change(repo_dir:, mode:, max_diff_bytes:)
      diffs = []
      diffs << run_git(%w[diff --cached], repo_dir: repo_dir) if mode == :staged || mode == :all
      diffs << run_git(%w[diff], repo_dir: repo_dir) if mode == :worktree || mode == :all

      content = diffs.join("\n")
      content = content.byteslice(0, max_diff_bytes) if content.bytesize > max_diff_bytes
      content.match?(/BREAKING CHANGE:|BREAKING:/i)
    rescue StandardError
      false
    end
  end
end

