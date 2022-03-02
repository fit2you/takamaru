require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

require 'active_job'
require 'active_record'
require 'rails'
require 'rollbar'

require 'takamaru'

ActiveJob::Base.logger = Logger.new(nil)

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Schema.verbose = false
load 'fixtures/db/schema.rb'

Dir['spec/support/**/*.rb'].each { |f| require_relative(f.gsub(%r{^spec/}, '')) }
