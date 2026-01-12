# frozen_string_literal: true

require_relative 'lib/ruby_json_toon/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruby-json-toon'
  spec.version       = RubyJsonToon::VERSION
  spec.authors       = ['Jitendra Neema']
  spec.email         = ['jitendra.neema.8@gmail.com']

  spec.summary       = 'Convert JSON to TOON (Token-Oriented Object Notation)'
  spec.description   = 'Lightweight Ruby library for converting JSON data to TOON format, achieving 30-60% token reduction for LLM applications'
  spec.homepage      = 'https://github.com/jitendra-neema/ruby-json-toon'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.files = Dir['lib/**/*.rb', 'README.md', 'CHANGELOG.md', 'LICENSE']
  spec.require_paths = ['lib']

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'documentation_uri' => 'https://rubydoc.info/gems/ruby-json-toon',
    'rubygems_mfa_required' => 'true'
  }

  # Development dependencies
  spec.add_development_dependency 'benchmark-ips', '~> 2.12'
  spec.add_development_dependency 'memory_profiler', '~> 1.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'rubocop-rake', '~> 0.7'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.0'
end
