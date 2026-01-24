#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/kk/git/version'

Gem::Specification.new do |spec|
  spec.name = 'kk-git'
  spec.version = KKGit::VERSION
  spec.authors = ['kk']
  spec.email = ['']

  spec.summary = 'Git 辅助工具：自动生成 Conventional Commit 信息'
  spec.description = '根据当前 Git repo 的变更（暂存/工作区）自动生成 Conventional Commits 格式的 commit message，便于 Rake/脚本调用。'
  spec.homepage = ''
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1'

  spec.files =
    Dir.glob('{exe,lib}/**/*', File::FNM_DOTMATCH).reject do |path|
      File.directory?(path)
    end
  spec.bindir = 'exe'
  spec.executables = ['kk-git']
  spec.require_paths = ['lib']

  spec.metadata['rubygems_mfa_required'] = 'true'
end

