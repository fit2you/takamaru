class DummyShadowable < ActiveRecord::Base
  include Takamaru::Shadowable
  has_shadow_attributes :attribute_1, :attribute_2
  has_shadow_client DummyClient, finder_method: :dummy_finder_method, finder_by_method: :dummy_finder_by_method
end
