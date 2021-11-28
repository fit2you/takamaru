require 'app/models/takamaru/application_model'

module Takamaru
  class CommitLog < ApplicationModel
    validates :exchange_name, presence: true
    validates :payload, presence: true
  end
end
