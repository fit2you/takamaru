require_relative 'lib/takamaru/version'

Gem::Specification.new do |spec|
  spec.authors = ['Matteo Panara']
  spec.email = ['matteo.panara@gmail.com']
  spec.summary = 'Transactional outbox and RabbitMQ messaging for Sasori Rails services'
  spec.description = 'Publishes model changes through a transactional outbox and consumes them from RabbitMQ.'
  spec.homepage = 'https://github.com/fit2you/takamaru'
  spec.license = 'MIT'

  spec.files = Dir['lib/**/*', 'CHANGELOG.md', 'README.md', 'UPGRADING.md'].reject { |f| File.directory?(f) }
  spec.name = 'takamaru'
  spec.required_ruby_version = '>= 3.1'
  spec.version = Takamaru::VERSION

  spec.add_runtime_dependency('activejob', '>= 7.0', '< 9.0')
  spec.add_runtime_dependency('activerecord', '>= 7.0', '< 9.0')
  spec.add_runtime_dependency('bunny', '~> 2.19')
  spec.add_runtime_dependency('railties', '>= 7.0', '< 9.0')

  spec.add_development_dependency('brakeman')
  spec.add_development_dependency('bundler-audit')
  spec.add_development_dependency('byebug')
  spec.add_development_dependency('database_cleaner-active_record')
  spec.add_development_dependency('factory_bot')
  spec.add_development_dependency('generator_spec')
  spec.add_development_dependency('pg', '~> 1.6')
  spec.add_development_dependency('rspec-rails')
  spec.add_development_dependency('rubocop')
  spec.add_development_dependency('rubocop-performance')
  spec.add_development_dependency('rubocop-shopify')
  spec.add_development_dependency('rubycritic')
  spec.add_development_dependency('simplecov')
end
