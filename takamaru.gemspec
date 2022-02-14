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
  spec.required_ruby_version = ['>= 2.4.10', '< 3.2']
  spec.version = Takamaru::VERSION

  spec.add_runtime_dependency('httparty', ['~> 0.20.0'])
  spec.add_runtime_dependency('rails', ['>= 4.2.7.1', '< 7.1'])

  spec.add_development_dependency('bundler-audit')
  spec.add_development_dependency('byebug')
  spec.add_development_dependency('rspec-rails')
  spec.add_development_dependency('rubocop')
  spec.add_development_dependency('rubocop-shopify')
  spec.add_development_dependency('rubycritic')
  spec.add_development_dependency('simplecov')
end
