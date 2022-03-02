module Takamaru
  class CommitLog < ApplicationRecord
    validates :exchange_name, presence: true
    validates :payload, presence: true
  end
end
