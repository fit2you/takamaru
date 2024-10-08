require_relative 'lib/takamaru/version'

Gem::Specification.new do |spec|
  spec.authors = ['Matteo Panara']
  spec.email = ['matteo.panara@gmail.com']
  spec.summary = 'Messenger for Sasori'
  spec.description = 'This gem provides methods to publish and consume messages.'
  spec.homepage = ''
  spec.license = 'MIT'

  spec.files = Dir['lib/**/*', 'LICENSE'].reject { |f| File.directory?(f) }
  spec.name = 'takamaru'
  spec.required_ruby_version = ['>= 2.4.10']
  spec.version = Takamaru::VERSION

  spec.add_runtime_dependency('bunny')
  spec.add_runtime_dependency('httparty', ['~> 0.21'])
  spec.add_runtime_dependency('rails', ['>= 4.2.7.1', '< 8.0'])

  spec.add_development_dependency('brakeman')
  spec.add_development_dependency('bundler-audit')
  spec.add_development_dependency('byebug')
  spec.add_development_dependency('database_cleaner-active_record')
  spec.add_development_dependency('factory_bot')
  spec.add_development_dependency('generator_spec')
  spec.add_development_dependency('rollbar')
  spec.add_development_dependency('rspec-rails')
  spec.add_development_dependency('rubocop')
  spec.add_development_dependency('rubocop-performance')
  spec.add_development_dependency('rubocop-shopify')
  spec.add_development_dependency('rubycritic')
  spec.add_development_dependency('simplecov')
  spec.add_development_dependency('sqlite3', '~> 1.4')
  spec.add_development_dependency('vcr')
  spec.add_development_dependency('webmock')
  spec.add_development_dependency('webrick', '~> 1.8.2')
end
