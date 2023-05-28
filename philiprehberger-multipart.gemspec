# frozen_string_literal: true

require_relative 'lib/philiprehberger/multipart/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-multipart'
  spec.version = Philiprehberger::Multipart::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']

  spec.summary = 'Multipart/form-data builder and parser with MIME type detection and streaming support'
  spec.description = 'Build and parse multipart/form-data request bodies with a clean DSL for adding text fields ' \
                     'and file uploads, including automatic MIME type detection, IO streaming, boundary generation, ' \
                     'and content type headers.'
  spec.homepage = 'https://philiprehberger.com/open-source-packages/ruby/philiprehberger-multipart'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/philiprehberger/rb-multipart'
  spec.metadata['changelog_uri'] = 'https://github.com/philiprehberger/rb-multipart/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/philiprehberger/rb-multipart/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
