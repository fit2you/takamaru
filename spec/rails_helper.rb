require 'spec_helper'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Schema.verbose = false
load 'fixtures/db/schema.rb'

class DummyClient < ApplicationClient
  class << self
    def dummy_finder_method(id)
    end

    def dummy_finder_by_method(attribute, value)
    end
  end
end

class DummyModel < ActiveRecord::Base
  include Takamaru::Shadowable
  has_shadow_attributes :attribute_1, :attribute_2
  has_shadow_client DummyClient, finder_method: :dummy_finder_method, finder_by_method: :dummy_finder_by_method
end
