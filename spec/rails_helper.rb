require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

require 'active_job'
require 'active_record'
require 'byebug'
require 'rails'
require 'rspec/rails/matchers'

require 'takamaru'

Rails.logger = Logger.new(nil)

ActiveJob::Base.logger = Logger.new(nil)
ActiveJob::Base.queue_adapter = :test

# A dedicated database: the schema is loaded with force and the tables are truncated before the suite
database = {
  adapter: 'postgresql',
  database: ENV.fetch('POSTGRES_TEST_DBNAME', 'takamaru_test'),
  host: ENV.fetch('POSTGRES_HOST', 'postgresql'),
  password: ENV.fetch('POSTGRES_PASSWORD', 'password'),
  username: ENV.fetch('POSTGRES_USER', 'user'),
}
begin
  ActiveRecord::Base.establish_connection(database)
  ActiveRecord::Base.connection.verify!
rescue ActiveRecord::NoDatabaseError
  ActiveRecord::Base.establish_connection(database.merge(database: 'postgres'))
  ActiveRecord::Base.connection.create_database(database.fetch(:database))
  ActiveRecord::Base.establish_connection(database)
end
ActiveRecord::Schema.verbose = false
load 'fixtures/db/schema.rb'

Dir['spec/support/**/*.rb'].each { |f| require_relative(f.gsub(%r{^spec/}, '')) }

RSpec::Matchers.define_negated_matcher(:not_change, :change)

RSpec.configure do |config|
  config.include(RSpec::Rails::Matchers)

  config.before do
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    Takamaru.config.application_name = 'rails_application'
    Takamaru.config.error_handler = ->(error, _context) { raise error }
    Takamaru.config.publishing_enabled = true
    Takamaru.config.rabbitmq = { hostname: 'localhost', password: 'guest', port: 5672, username: 'guest' }
  end
end
