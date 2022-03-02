module Takamaru
  class UnhandledMessageLog < ApplicationRecord
    validates :consumer, presence: true
    validates :payload, presence: true
  end
end
