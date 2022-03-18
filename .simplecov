SimpleCov.configure do
  add_filter '/spec/'

  add_group 'Clients', 'lib/app/clients'
  add_group 'Consumers', 'lib/app/consumers'
  add_group 'Generators', 'lib/generators'
  add_group 'Jobs', 'lib/app/jobs'
  add_group 'Models', 'lib/app/models'

  coverage_dir 'tmp/simplecov'
  enable_coverage :branch

  track_files '{lib}/**/*.rb'
end
SimpleCov.minimum_coverage(ENV['DB'] == 'postgres' ? 97.3 : 92.4)
