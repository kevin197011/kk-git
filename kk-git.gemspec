#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/kk/git/version'

Gem::Specification.new do |spec|
  spec.name = 'kk-git'
  spec.version = KKGit::VERSION
  spec.authors = ['kk']
  spec.email = ['']

  spec.summary = 'Git helper: generate Conventional Commits messages'
  spec.description = 'Generate Conventional Commits commit messages from current git changes (staged/worktree), designed for Rake/script usage.'
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

