Gem::Specification.new do |s|
  s.name = 'takamaru'
  s.version = '0.0.0'
  s.summary = 'Messenger for Sasori'
  s.description = 'This gem provides methods to publish and consume messages.'
  s.authors = ['Matteo Panara']
  s.email = 'matteo.panara@gmail.com'
  s.files = ['lib/takamaru.rb']
  s.homepage = 'https://rubygems.org/gems/hola'
  s.license = 'MIT'

  s.add_development_dependency('bundler-audit')
  s.add_development_dependency('byebug')
  s.add_development_dependency('rspec-rails')
  s.add_development_dependency('rubocop')
  s.add_development_dependency('rubocop-shopify')
  s.add_development_dependency('rubycritic')
  s.add_development_dependency('simplecov')
end
