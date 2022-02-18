class DummyShadowable < ActiveRecord::Base
  include Takamaru::Shadowable
  has_shadow_attributes :attribute_1, :attribute_2
  has_shadow_client DummyClient
end
